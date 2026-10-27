/// The written topics of the AI assistant's manual: the drawing model and
/// its connection rules, the design run, system flows, verification,
/// terrain, machines, wiring and the common mistakes. They state how the
/// engine works (network_builder.dart, designer.dart, advisor.dart…) and
/// take their numbers from its defaults; the test of the manual checks
/// that every tool, parameter and message code they name exists.
library;

import '../../core/design/advisor.dart' show connectReach;
import '../../core/model/entities.dart';
import '../../core/model/project.dart';
import '../i18n.dart' show languageNames, supportedLanguages;
import 'agent_tools.dart';
import 'agent_tools_edit.dart' show defaultLayerOf, entityKeys;
import 'manual_entities.dart' show numText, sampleEntity;

String _n(double v) => numText(v);

/// The "drawing" topic.
String drawingTopic(AgentToolbox b) {
  final p = b.p.params;
  final d = DesignParameters();
  final layers = <String, List<String>>{};
  for (final type in entityKeys.keys) {
    final e = type == 'pipe' ? null : sampleEntity(type);
    if (e != null) layers.putIfAbsent(defaultLayerOf(e), () => []).add(type);
  }
  layers.putIfAbsent(Layers.zonePipes, () => []).add('pipe (zone)');
  layers.putIfAbsent(Layers.mainlinePipes, () => []).add('pipe (mainline)');
  final georef = b.p.meta.georef;
  return '''# Drawing model and connection rules

## Coordinates, angles, elevations
- The plane is in metres, x east and y north. With a georeference (set_site) the origin (0, 0) is the georeferenced point and the plane a local transverse Mercator grid around it, so plane distances are true metres${georef == null ? '; this project has none yet' : ' (this project: ${georef.crsName})'}. Without one the coordinates are local and nothing can be put on a map: base maps, elevation and climate downloads and KML/KMZ/GeoJSON/GPX need it.
- Angles are degrees counter-clockwise from east (+x): 0 east, 90 north, 180 west, 270 south. That holds for direction_deg, rotation_deg and angle_deg of the tools, a pivot's "ang", an outlet's "rot" (its wetted arc starts there and runs counter-clockwise over "arc") and text and symbol "rot"; arc items store radians.
- Units are SI in every tool (read_manual "units").
- Every node takes the ground elevation of the terrain model at its point, less the depth of its items; a junction's z fixes it; a water supply's node stands at ground + wl (its water level). Without terrain data the ground is 0 m everywhere and the design is flat (no_terrain).

## Layers
New items go to their type's layer unless "layer" is given: ${[for (final e in layers.entries) '${e.key} (${e.value.join(', ')})'].join('; ')}. A locked layer refuses every change to its items; a hidden layer is still designed and exported. edit_layers manages them.

## Scopes, nodes and splitting (how the design builds its network)
1. There are two networks. The mainline: pipes with scope "mainline", water supplies, pivots, and the pumps, devices, outlets and junctions with scope "mainline". The zones: pipes with scope "zone", every sprayline and tape, and the point items with scope "zone". A node only joins items of its own scope. A control valve is the one bridge: at its position it makes a mainline node and a zone node, joined by the valve.
2. Points closer than connectTolerance (now ${_n(p.connectTolerance)} m; default ${_n(d.connectTolerance)} m) are one node.
3. A point item (outlet, junction, pump, device, valve, supply, pivot centre) lying on a pipe or lateral of its scope, at a vertex or on the interior, joins it; on the interior it splits it there. A valve splits the zone and the mainline items it lies on.
4. The first and last point of a pipe or lateral lying on the interior of another pipe or lateral of the same scope splits that one there: a tee. Interior vertices join only where another item has a node at the same point.
5. Nothing else joins. Pipes that cross without a shared point stay apart (pipes_cross); a lateral passing over a submain without an end on it is not fed.
6. A zone is every zone node reached from its valve's zone node through zone items; two valves must not reach each other's nodes (zone_overlap). The mainline is every mainline node reached from the supplies, never through a valve.
7. What is not reached is unconnected: left out of the design and listed by the design check (unconnected). The correction connect moves such an item onto the nearest compatible one within ${_n(connectReach(b.p))} m (max of 2 m and 20 × the tolerance).

## Item by item
- waterSupply: the mainline starts at it.
- pump, misc: in line on a pipe of their scope, which they split; the side fewer pipe hops from a supply (mainline) or from the zone valve (zone) is the upstream side. Draw them on the pipe between the supply and the demands, in flow order (pump, check valve, filter, meter…); a device at a free pipe end has nothing downstream.
- controlValve: where the mainline ends and the zone's first pipe starts; the zone pipes start at its position. generate_block, subdivide_field, tree_rings and layout_sprinklers (routing) place the valve outside the submain with a short zone stub; end the mainline exactly at the valve position they report.
- pipe: zone pipes are submains, manifolds and stubs; mainline pipes the main network from the supply to the valves, pivots and valve-in-head heads.
- sprayline, tape: start them on the submain (their emitters are counted from the first point) and keep them inside the field.
- outlet: on a pipe or lateral of its scope; heads on zone pipes behind one valve form a sprinkler zone; heads on the mainline are valve-in-head heads (read_manual "flows").
- pivot: its centre on a mainline pipe.
- Areas, terrain items, drawing items and notes never connect.

## Joining by construction
Give a point that must join the very coordinates of the point it joins (read them with list_entities or get_entity), or put it on the other item's line. After drawing, run_design or get_design_messages shows what is unconnected.''';
}

/// The "design" topic.
String designTopic(AgentToolbox b) => '''# The design run

run_design {mode}: "all" sizes the zone pipes, laterals and mainline; "zones" only zone pipes and laterals; "mainline" only the mainline; the rest is analysed as drawn. analyse_design sizes nothing. Both need a water supply and a zone valve or pivot. A run replaces the results; any later change to the drawing or the settings discards them (read the numbers again after designing again).

## What is sized
A pipe or sprayline is sized when it has no spec, or auto true; with auto false and a spec it is fixed. Candidates are the enabled catalogue pipes of its usage (lateral for spraylines, zone for zone pipes, mainline for mainline pipes) whose class (derated for warm water) holds the pressure found. Tapes are never sized. Up to maxLateralSizes / maxSubmainSizes / maxMainlineSizes diameters may follow each other along one item (telescoping, the largest upstream).
- sizingMethod lp (default): a linear programme for the least annual cost: the pipe price annualised with interestRate over termYears, plus, when tradeCapitalVsRunning, the energy of the head at the inlet (zoneHoursPerYear for zones, hoursPerYear shared by the system flows' durations for the mainline, at powerCostPerKwh and pumpEfficiency); subject to every emitter's pressure window, every valve's required pressure and the velocity limits; then checked with the full network solver and upsized where needed. lp_infeasible: no combination meets the limits (the closest is kept).
- sizingMethod greedy: velocity first, then the pressure window, then cost.

## Zones
Each zone network is solved with every emitter at its own pressure (q = k·h^x, lateral emitters lumped into at most maxNodesPerLateral nodes). The pressure after the valve is the one that gives the emitters, on average, their nominal pressure (the "head" of spraylines and outlets, the "inlet" of tapes); if the spread fits the window but sits off-centre it is moved to the middle. With the valve's "fixed" set, the zone is analysed at that pressure instead.
- Window of an emitter: the pressures that keep its flow within its nozzle's flow tolerance (default ±5 %, for x = 0.5 about −10 %/+10 % of the nominal pressure; a pressure-compensating emitter takes its whole range) inside the nozzle's min/max pressure; a tape: −30 %/+20 % of the inlet pressure inside its range (the tape model's tolerance). The zone window is the overlap of its emitters' windows, narrowed to nominal ± maxZoneVariationPct/2 when that is above 0. In window = every emitter inside.
- Zone results: flow, pressure after the valve, valve loss (from the valve model's curve at the zone flow; none without a model), required pressure before the valve (after + loss + elevation difference), lowest and highest emitter pressure against the window, uniformity (CU, DU, and EU with the nozzles' manufacturer CV and the emitters per plant), pipe velocities and classes, pipe cost, annual energy.
- Messages: cannot_meet_pressure_window, outlet_over_pressure, velocity_exceeded, pressure_rating_exceeded, valve_flow_out_of_range, not_converged.

## Mainline and supplies
The mainline is solved once for every system flow (read_manual "flows"); without system flows, once with every zone and pivot running together. Each valve draws its zone's flow and needs its required pressure; a pivot its machine flow and inlet pressure; a scheduled valve-in-head station its heads' nominal pressure.
- Water supply with calc true: it is given the pressure the worst demand needs (the supply's "needs" in the summary); when pumps or elevation already give more, it stays at 0 and the surplus shows as extra pressure at the valves.
- calc false: analysed at dh; demands short of pressure are reported (valve_pressure_deficit, pivot_pressure_deficit).
- dq > 0: a system flow drawing more gives supply_flow_exceeded (regroup with set_system_flows); mh > 0: a need above it gives supply_head_exceeded.
- Pumps add their curve's head at the flow, at speed × (mains frequency ÷ rated frequency); a pump with vfd > 0 is run at the speed that keeps that outlet pressure, between vmin and speed. Messages: pump_out_of_range, pump_suction_lift, pump_npsh, vfd_target_unreachable, vfd_below_min_speed, vfd_target_low.
- Devices take their loss at the flow; a PRV holds "set" downstream, a PSV "set" upstream, an FCV limits the flow to "setq".
- not_converged on a flow or a zone: its numbers are unreliable; the cause is usually a disconnected or odd piece of network.

## Results and costs
- The run_design summary gives the zones outside their window, every system flow's total flow and supply duty (flow, pressure available and needed), the valves short of pressure, pivots, the pipe segments over the velocity limit, the costs and the message counts. get_report_table gives every number (read_manual "reports"); get_design_messages explains every message.
- Costs, in the project currency: materials = the bill of materials at catalogue prices; annual capital = their annuity (interestRate, termYears); annual energy = the energy of every system flow (its pumps' head, or a calculated supply's needed head, times its flow, over its share of hoursPerYear) at powerCostPerKwh.
- Surge (checkSurge): the Joukowsky surge for valveClosureTimeS (0 = instantaneous) added to the highest static pressure is checked against each pipe's class (surge_rating_exceeded); run_analysis "transients" is the detailed check.
- Flushing: the drip zones with the tape ends open at flushingVelocity, keeping flushingMinEndHeadM at the ends (report flushing).
- Fittings (selectFittings) and couplers every pipeStickLengthM go into the bill of materials; fitting_missing when the catalogue lacks a fitting.

## Improving a design
auto_fix designs and applies the safe corrections (a booster pump on a mains connection waits for the user: apply_fix choosePump once they agree); optimize_design looks for a cheaper design without new errors; rank_pumps / apply_pump choose the pump; set_parameters changes the limits; the drawing (lateral lengths, submain position, zone split, emitter choice, a PRV) is the lasting fix for pressure problems.''';

/// The "flows" topic.
String flowsTopic(AgentToolbox b) => '''# System flows (shifts)
A system flow is a set of demands that run together, with a start hour and a duration (h): zone valves and pivots (by id) and valve-in-head stations. The mainline, the supply and the pump are designed for every flow: the largest decides the pump duty and the main pipe sizes. Without system flows the design runs every zone and pivot at once (one flow "All zones", 1 h), usually far more than the source gives.
- set_system_flows modes: auto packs the demands, largest first, into flows whose total stays within max_flow_m3h, else within the sum of the supplies' design flows (dq); with neither (a pumped or calculated supply without dq) there is no limit and every demand ends in one flow, so give max_flow_m3h (the well, pump or connection capacity) or max_valves. A demand alone above the limit gets a flow of its own and the design reports supply_flow_exceeded. all_together: one flow; one_at_a_time: a flow per demand, back to back from first_start_hour; replace: the flows given (demands by id, zone name, "vih:<station>" or a head's id); clear: none.
- Once flows exist, every zone valve and pivot must be in one (valve_not_in_flow, correction addMissingFlow); empty flows (flow_empty) and zero durations (flow_duration) are reported.
- Durations: the schedule report gives the hours each zone needs per event from the crop data of its area and its precipitation; set them with replace (duration_hours per flow).
- Energy: run_analysis "energy_grouping" finds the grouping with the least energy; apply_energy_grouping sets it. run_analysis "eps" simulates the day with the flows at their start hours.
- Valve-in-head stations: outlets with scope mainline. Heads sharing a "zone" name are one station ("vih:<name>"), a head with none is a station of its own (its id). A station a flow lists runs only in the flows that list it, at its heads' nominal pressure; a station no flow lists runs in every flow (vih_not_in_flow warns).''';

/// The "verification" topic.
String verificationTopic(AgentToolbox b) {
  final d = DesignParameters();
  return '''# Verifying a design
Design the final drawing (run_design, or analyse_design after a manual change: results belong to the drawing they were computed for), then check:
1. Messages (get_design_messages): no error left; every warning fixed or explained to the user. auto_fix applies the safe corrections; apply_fix one; read_manual "messages" has every code.
2. Pressure windows (zones table: lowest and highest emitter pressure against the allowed window): every zone inside. Outside: let the design size the pipes, shorten the laterals, move the submain (feed from the middle or the high side), split the zone, use pressure-compensating emitters on slopes, or add a PRV before the valve.
3. Supply and pumps (mainline and devices tables, per system flow): the flow within the source's capacity (dq), the pressure available at least what is needed, each pump inside its curve range (pump_out_of_range), surface pumps within their suction lift (pump_suction_lift). rank_pumps and apply_pump choose one; design again after.
4. Velocities (pipes table, ⚠ rows): within maxLateralVelocity (default ${numText(d.maxLateralVelocity)} m/s), maxZoneVelocity (${numText(d.maxZoneVelocity)}) and maxMainlineVelocity (${numText(d.maxMainlineVelocity)}).
5. Pressure classes (pipes and surge tables): no pressure_rating_exceeded or surge_rating_exceeded; valveClosureTimeS set for the real valves.
6. Uniformity (zones table): EU for drip and micro zones, CU and DU for sprinklers (run_analysis "uniformity" gives the densogram over the areas). The engine's classes: 94 % and above excellent, 90 good, 80 fair, 70 poor (read_manual "values").
7. System flows: every zone in one, each flow within the supply, durations from the schedule report.
8. Wiring when controllers exist: stations enough, voltage at every solenoid (electrical table, elec_* messages).
A design is finished when the request is met, the last run is on the current drawing, no error remains and every remaining warning has been reported with its reason. Report what the tools showed; say plainly what was not run or not checked.''';
}

/// The "terrain" topic.
String terrainTopic(AgentToolbox b) {
  final p = b.p;
  final tr = b.terrain;
  final contours = p.entities.whereType<ContourEntity>().where((e) => !e.derived).length;
  final spots = p.entities.whereType<SpotHeightEntity>().length;
  final dem = p.entities.whereType<SpotHeightEntity>().where((e) => e.isDem).length;
  final breaklines = p.entities.whereType<BreaklineEntity>().length;
  return '''# Terrain, georeference, base maps
- Terrain data: contours (z), spot heights (z), breaklines (zs per vertex) and the elevation points download_terrain adds (spot heights named "DEM …" on the DEM layer). Contours generated from the model (gen) are drawn but are not data. terrainMethod tin (default) triangulates the data (contour vertices taken every terrainDensify m) and interpolates linearly; idw weights by inverse distance and is defined outside the data too. get_elevations reads the model at points; the vision tools (terrain_info, terrain_profile, terrain_picture) show it.
- In this project: $contours contours, $spots spot heights ($dem downloaded), $breaklines breaklines; the model ${tr.isEmpty ? 'is empty: every elevation is 0 m' : 'has ${tr.sampleCount} points'}; method ${p.params.terrainMethod.name}, densify ${numText(p.params.terrainDensify)} m.
- Effect on the design: a node 1 m lower has 1 m more pressure; zone windows, supply needs and pump duties follow the ground. Without terrain data the design is flat (no_terrain).
- Georeference (set_site): the drawing origin at a WGS84 latitude/longitude${p.meta.georef == null ? ' (none yet)' : ' (set: ${p.meta.georef!.crsName})'}. find_site turns an address into coordinates. Changing an existing georeference moves the drawing on the map, so it is always confirmed.
- Base map (set_base_map): imagery or maps under the drawing, a view setting that needs the georeference. view_snapshot pictures the drawing over it with a metre grid, to trace fields, buildings and roads.
- download_terrain: terrainTiles (30 m SRTM, default) or openMeteo (90 m Copernicus) every 10–200 m (default 25), over the drawing (or the view). It replaces earlier downloads and keeps the user's own data unless replace_own; it reports when the user's own heights sit on another datum (ask before mixing them).
- download_climate: daily weather of the last years (openMeteo default, or nasaPower) turned into monthly normals (ETo, rain, dependable rain, radiation) stored in the project for the agronomy reports.
- Imported surveys (import_attachment: DXF/DWG contours and points, LandXML surfaces, GeoTIFF elevations, CSV points, LAS clouds) become terrain items too.

## Imported drawings on the map
GIS files (KML/KMZ, GeoJSON, GPX, a shapefile with its .prj) carry their coordinate system: they land in place, and georeference a project that has none. A CAD drawing (DXF, DWG, DGN, PDF) keeps its own coordinates and carries no georeference. import_attachment returns the extent of what came in (the items are selected) and the next step when it is not on the map yet:
- UTM coordinates (eastings 100–900 km, northings up to 10 000 km) in a project without a georeference: set_georeference {mode "utm", zone, north, easting_m 0, northing_m 0} reads them as they are; zone and hemisphere from the drawing's title block, the user, or the site (zone = floor((longitude + 180) / 6) + 1). In a project already georeferenced in that zone: transform_entities {selected true, operation "move", dx = −origin easting, dy = −origin northing}.
- Local coordinates: set_site at the address (the origin [0, 0] goes there; nothing moves), then two points recognised both in the drawing and on a satellite picture of the site (view_snapshot with base_map "satellite", image_to_world) and align_entities {selected true, from_a, to_a, from_b, to_b}.
- Check with view_snapshot {region "drawing", base_map "satellite"} before tracing or designing on it.''';
}

/// The "interface" topic: what the user does in the program's menus — the
/// functions only the user can run, with their menu paths in the user's
/// language — and the interface language.
String interfaceTopic(AgentToolbox b) {
  final t = b.t;
  String m(List<String> keys) => [for (final k in keys) t(k).replaceFirst(RegExp(r'…$'), '')].join(' → ');
  final langs = [for (final l in supportedLanguages) '$l (${languageNames[l] ?? l})'].join(', ');
  return '''# The interface: what the user does there
Name the menus as the user's screen shows them (the paths below are in the interface language). These functions need the user's hands, device or keys, so no tool runs them: point the user to them.
- The interactive tutorial, a guided tour of the program for a new user: ${m(['menu.help', 'help.tutorial'])} (the welcome screen offers "${t('welcome.tutorial')}" too).
- Walking the field with the device's GPS (a phone or tablet on site): ${m(['menu.draw', 'gps.submenu', 'gps.walkStart'])}, walk round the field, then ${t('gps.walkArea')}, ${t('gps.walkOutline')} or ${t('gps.walkLine')}; "${t('gps.mark')}" adds a point; ${m(['menu.view', 'gps.menu'])} shows where the device is. A project without a georeference takes one from the first position. The walked outline is then an item of the drawing (list_entities finds it) that the tools use, e.g. as the area of generate_block.
- The Google base maps need the user's own Map Tiles API key: ${m(['menu.view', 'view.baseMap', 'view.baseMap.googleKey'])}. You never handle keys.
- Files on the user's computer: ${m(['menu.file', 'file.open'])} and ${m(['menu.file', 'file.importDrawing'])}; or the user attaches them to the conversation for you (open_attached_project, import_attachment).
- The version and the links of the program: ${m(['menu.help', 'help.about'])}; the keyboard shortcuts: ${m(['menu.help', 'help.shortcuts'])} (list_commands lists them for you).

What you change for the user when asked:
- The interface language, ${m(['menu.view', 'view.language'])}: set_setting {"values": {"view.language": code}}, one of $langs. It applies to every open tab and stays in this browser.
- The theme (view.theme), the reports panel (view.reports_panel), the base map (set_base_map), autosave (app.autosave): get_setting lists every setting.''';
}

/// The "machines" topic.
String machinesTopic(AgentToolbox b) => '''# Centre pivots and linear moves
A pivot item (create_entities type "pivot", or fit_pivot) is a demand on the mainline at its centre; the design takes its flow and inlet pressure from the machine:
- Flow = irrigated area × gross depth ÷ hours per cycle, plus the end gun (qg). Irrigated radius = r + throw; area = π × radius² × sector/360 for a pivot, radius × travel for a linear.
- Inlet pressure = the larger of the end pressure (hend) and the end gun pressure (hg) + the span pipe friction (flow falling along the machine: ∝ distance for a pivot, uniform for a linear; the pipe spec, or idmm and c) + the highest ground rise along the span + the pipe height (hp) + the machine losses (hm); every tower is checked too.
- Peak application rate at the outer end = 4/π × the mean (2 Q ÷ (R × ww) for a pivot); with imax > 0 a higher rate gives pivot_app_rate.
- The span pipe velocity is checked against 3 m/s; pivot_no_flow (depth or hours missing), pivot_no_end_pressure.
- Workflow: fit_pivot places the largest machine a field holds (or create it with p, r, sector, ang); end a mainline pipe at its centre; include it in the system flows like a zone; run_design gives the pivots and pivotSpans tables and pivot_pressure_deficit when the mainline delivers too little.
- The sprinkler package, drive and timer, corner arm, variable-rate prescription and electrical design (tables pivotPackage, pivotPackageSummary, pivotTimer, cornerArm, vri, pivotElectrical) come from the machine data ("mach"), set in the machine dialog of the properties panel or by an operation (find_operations "pivot").''';

/// The "electrical" topic.
String electricalTopic(AgentToolbox b) {
  final d = DesignParameters();
  return '''# Valve wiring
- A controller (type "controller" {p, st, v, sim}) powers the valve solenoids through wire routes (type "wire" {pts}) drawn from it: a valve, master valve or pump relay on a route's vertex or on a route is reached; routes sharing a vertex connect. route_wires draws the routes along the pipe trenches and allocates the stations (zone valves first, by distance).
- With a controller or routes in the drawing the design checks the wiring (electrical table): each valve's station conductor and the shared common conductor along the routes plus wireSlackPct (default ${numText(d.wireSlackPct)} %), the smallest enabled catalogue wire that keeps every solenoid at solenoidMinVolts (default ${numText(d.solenoidMinVolts)} V) or more with the inrush (${numText(d.solenoidInrushA)} A) and holding (${numText(d.solenoidHoldingA)} A) currents of the valves open together (sim, or the system flows).
- Messages: elec_no_controller, elec_unwired, elec_wire_orphan, elec_ctrl_unwired, elec_no_wires, elec_stations (more valves than stations: raise st), elec_voltage (too little voltage: thicker or enabled wires, a closer controller), elec_simultaneous.
- Master valves (a master-kind device, or a control valve placed as a device on the mainline) and pump-start relays take stations after the zone valves, or the controller's dedicated terminals (route_wires options). Two-wire decoder systems: route_wires mode "steiner".''';
}

/// The "mistakes" topic.
String mistakesTopic(AgentToolbox b) => '''# Common mistakes and what shows them
- A lateral drawn beside the submain instead of starting on it: its emitters are left out (unconnected, zone_no_emitters). Start every lateral on the submain, at the same point.
- The mainline stops short of the valve or reaches it on the zone side: the valve is unconnected and the zone empty (unconnected, zone_no_emitters). End the mainline exactly at the valve position.
- A zone pipe drawn with scope "mainline" (or the reverse): the two never join; the zone is empty or the mainline dead-ends (zone_no_emitters, mainline_dead_end).
- Pipes that cross without a shared vertex are not joined (pipes_cross; correction joinCrossing).
- A pump or filter beside the pipe instead of on it: unconnected. At a free pipe end it feeds nothing.
- No water supply, or a supply away from the mainline start: no_supply, or everything on the mainline unconnected.
- Many zones and no system flows: every zone runs at once, the supply flow is exceeded and the pump and mainline come out huge (supply_flow_exceeded). Set the flows (set_system_flows) before judging pump and mainline sizes.
- set_system_flows "auto" without max_flow_m3h on a supply whose dq is 0: one flow with every zone. Give the source capacity.
- calc false with dh 0: supply_no_head. Give the pressure the source has, or let the design calculate it.
- An emitter pressure ("head", "inlet") outside its nozzle or tape range: emitter_head_range (correction nominalEmitterHead).
- A zone valve whose flow range misses the zone flow: valve_flow_out_of_range (resizeValve); a valve with no model counts no loss.
- Pipes fixed too small: velocity_exceeded, cannot_meet_pressure_window (autoSizePipes).
- Laterals too long, or the slope across the zone too steep: cannot_meet_pressure_window. Shorter laterals, a centre-fed submain, the submain on the high side, PC emitters or a PRV.
- A surface pump over deep water: pump_suction_lift (submersiblePump).
- Sprays and rotors, or unmatched part circles, in one zone: zone_mixed_emitters.
- The same items pasted twice: duplicate_item; two valves with one zone name: duplicate_zone_name.
- Quoting numbers from before a change: every change discards the results; design again first.
- Units: tool inputs are SI. 10 m³/h is 0.002778 m³/s and 2 bar is 20.4 m of head; a flow given in m³/h where m³/s is expected is 3600 times too large.''';
