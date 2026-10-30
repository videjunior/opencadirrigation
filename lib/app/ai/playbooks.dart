/// Design playbooks: step-by-step workflows for each kind of project, written
/// from how the shipped examples are built. The AI agent reads one with the
/// get_playbook tool; the system prompt lists only their ids and when to use
/// them. English (the model's working language).
library;

import '../examples.dart' show ExampleId;

/// One design workflow: the order of work, the tools and their typical
/// inputs for one kind of project.
class Playbook {
  const Playbook({required this.id, required this.title, required this.when, required this.examples, required this.steps});

  /// Tool argument, e.g. `drip_orchard`.
  final String id;
  final String title;

  /// One line: when to use it (shown in the system prompt).
  final String when;

  /// Examples built this way (read_example / open_example).
  final List<ExampleId> examples;

  /// Markdown: numbered steps naming the tools and their typical inputs and values.
  final String steps;
}

/// Every playbook, in the order the system prompt lists them.
const playbooks = <Playbook>[
  Playbook(
    id: 'drip_orchard',
    title: 'Orchards, vineyards and bananas: drip or micro-sprinklers along the rows',
    when: 'Orchards, vineyards, bananas and other tree or vine rows on drip or micro-sprinklers (a lateral per row, a valve per block).',
    examples: [ExampleId.orchard, ExampleId.bananas],
    steps: _dripOrchard,
  ),
  Playbook(
    id: 'row_crop_tape',
    title: 'Row crops and sugarcane on drip tape or dripline',
    when: 'Row crops, field vegetables and sugarcane on drip tape or dripline, on the surface or buried (equal blocks, one or two per shift).',
    examples: [ExampleId.rowCrop, ExampleId.sugarcane],
    steps: _rowCropTape,
  ),
  Playbook(
    id: 'greenhouse',
    title: 'Greenhouses and tunnels on PC dripline',
    when: 'Greenhouses, tunnels and shade houses: PC dripline along the beds, one zone per house, a tank, a small pump and a disc filter.',
    examples: [ExampleId.greenhouse],
    steps: _greenhouse,
  ),
  Playbook(
    id: 'landscape_sprinklers',
    title: 'Gardens and landscapes: sprays, rotors and dripline by hydrozone',
    when: 'Residential or commercial gardens: sprays and rotors on lawns, dripline in beds, a valve per hydrozone, mains with meter and backflow, wiring.',
    examples: [ExampleId.garden],
    steps: _landscapeSprinklers,
  ),
  Playbook(
    id: 'sports_field',
    title: 'Sports turf: a sprinkler grid for a football pitch',
    when: 'Football pitches and other sports turf: heads in rows along the touchlines with matched part circles, a zone per row, night shifts.',
    examples: [ExampleId.sportsField],
    steps: _sportsField,
  ),
  Playbook(
    id: 'golf_hole',
    title: 'Golf hole: green, tee and fairway heads',
    when: 'Golf holes and courses: rotors round the greens, tees and fairway grids, zones by area, a pond pump and a header along the cart path.',
    examples: [ExampleId.golf],
    steps: _golfHole,
  ),
  Playbook(
    id: 'centre_pivot',
    title: 'Centre pivots, full circle or sector',
    when: 'Centre pivots, full circle or sector, with or without an end gun: fitting the machine, its depth and pressures, the source and the mainline.',
    examples: [ExampleId.pivot, ExampleId.sectorPivot],
    steps: _centrePivot,
  ),
  Playbook(
    id: 'linear_move',
    title: 'Linear (lateral) move machines',
    when: 'Linear (lateral) move machines on long rectangular fields, fed at the inlet end from a canal, a ditch or a mainline.',
    examples: [ExampleId.linear],
    steps: _linearMove,
  ),
  Playbook(
    id: 'gravity_drip',
    title: 'Gravity-fed drip from a reservoir above the field',
    when: 'Gravity-fed drip from a reservoir, tank or spring above the field: no pump; gate valve, pressure reducing valve and filter on the line down.',
    examples: [ExampleId.gravity],
    steps: _gravityDrip,
  ),
  Playbook(
    id: 'nursery',
    title: 'Plant nurseries: overhead micro-sprinklers per bed',
    when: 'Plant nurseries and container beds: overhead micro-sprinklers on a square grid, one zone per bed, short shifts.',
    examples: [ExampleId.nursery],
    steps: _nursery,
  ),
  Playbook(
    id: 'pasture',
    title: 'Pastures and paddocks: impact sprinkler spray lines',
    when: 'Pastures, paddocks and forage on sprinklers: impact sprinkler laterals on a wide grid, one zone per paddock, night shifts.',
    examples: [ExampleId.pasture],
    steps: _pasture,
  ),
  Playbook(
    id: 'coffee_contours',
    title: 'Coffee and other perennials on contour lines',
    when: 'Coffee, tea or other perennials planted along contour lines on hillsides: level PC drip laterals, submains and mainline up the slope.',
    examples: [ExampleId.coffee],
    steps: _coffeeContours,
  ),
];

/// The playbook named [id] (case, spaces and hyphens forgiven), or null.
Playbook? playbookById(String id) {
  final key = id.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
  for (final p in playbooks) {
    if (p.id == key) return p;
  }
  return null;
}

// ---------------------------------------------------------------- orchards, vineyards, bananas

const _dripOrchard = r'''Keep the to-do list with update_todo; in Plan-first mode have the plan approved with present_plan before the first change.
Tool inputs are SI as in the project file: metres, m³/s (10 m³/h = 0.00278 m³/s), metres of head (1 bar ≈ 10.2 m); options ending in _m3h take m³/h.
Catalogue ids below are the default catalogue's, as the examples use them: confirm each with search_catalog (another catalogue has other ids).
References: read_example orchard (a micro-sprinkler block and a drip block on a shallow well) and bananas (PC micro-sprinklers, deep well).

1. Brief. Read get_notes, then ask what is still missing with ask_user (2–4 options plus free text each) and record it with update_notes:
   - crop and spacing, row × plant (citrus 6 × 4 m / vines 3 × 1.5 m / bananas 5 × 2.5 m / other), and the tree age (young trees: rings);
   - emission (a micro-sprinkler per tree: wide wetting, sandy soil, bananas / dripline along each row / both, a block of each);
   - soil (sand / loam / clay) and the water source: shallow well (water within about 6 m), deep well (water level, yield in m³/h),
     reservoir or canal, or a pressurised connection (pressure and flow);
   - power at the source, irrigation hours per day, budget, preferred brand.
2. Site. find_site with the address, set_site; then look before drawing (the pictures are for you: the user's screen keeps its base map;
   set_base_map "satellite" only when the user wants to see it too):
   - view_snapshot {region "bbox", bbox = the farm with a margin, base_map "satellite"}: the blocks, tree rows and their direction, roads,
     the well, buildings and trees to avoid; view_snapshot {snapshot, pixel_bbox} zooms into a corner at full resolution.
   - download_terrain (the examples slope 0.5–1 %), terrain_info (how dense the data are, where they are thin), then terrain_picture
     {region "bbox", bbox, base_map "satellite"} for the relief and its contours over the image (colour "slope" shows the steep parts);
     download_climate for ETo and rain.
   - Trace what you see: trace_region {snapshot, pixel [px, py] well inside a field, lawn or pond} outlines it by image analysis, far
     more exactly than by eye (check its picture; blur_m 3–6 for wide rows and orchards, tolerance when it leaks or stops short; it
     cannot split two fields of one crop with no visible limit). For the rest pick the corners on the picture: image_to_world
     {snapshot, pixels, closed true} gives the coordinates in metres, preview_geometry {shapes [{kind "polygon", pts, label}],
     base_map "satellite"} checks them over the image (nothing is created); then create them in the next step.
   If the user attached a survey or plan, import_attachment it instead of tracing: a DXF or DWG keeps its own coordinates, so follow the
   placement its result gives (set_georeference "utm" for UTM coordinates, else align_entities onto two points of the satellite picture),
   then check it with view_snapshot {region "drawing", base_map "satellite"}.
3. Blocks. One area per irrigation block, all in one create_entities call: type "area" {pts, name, crop, ck "crop.citrus" /
   "crop.grape" / "crop.banana", soil "soil.loam", im "localized", wb true, eto, kc, awc, root, mad, eff, psp, rsp, wf, epp}. Example
   values: citrus eto 5.5, kc 0.7, awc 120, root 0.8, mad 0.5, eff 0.9; vines kc 0.7, root 0.6, mad 0.45, wf 0.4, epp 4; bananas kc 1.1,
   awc 130, root 0.6, mad 0.35, wf 0.7. Size the blocks so one shift fits the source (the example blocks are 0.5–0.6 ha drawing
   6–20 m³/h). For a large field, subdivide_field {area, lateral, outlet/nozzle/head_m or tape as below, lateral_spacing_m = row
   spacing, max_block_flow_m3h = the flow of one shift, road_width_m 4} cuts the blocks and fills them instead.
4. Laterals. generate_block on each block area (one call per block, all in one reply), one lateral per tree row, direction_deg along the
   rows (0 = east, 90 = north):
   - micro-sprinklers (search_catalog kind "emitter" query "micro"): lateral "sprayline" with outlet, nozzle and head_m always together,
     emitter_spacing_m = tree spacing, lateral_spacing_m = row spacing. Orchard: micro / m50 (50 L/h, R 3.5 m) at 15 m, 3.5 m apart on
     rows 4 m apart; bananas: micro_pc / mpc70 (70 L/h PC, R 4.5 m) at 20 m on a 5 × 5 m grid.
   - dripline (search_catalog kind "tape"): lateral "tape" with tape and inlet_head_m (the orchard's drip block: drip16_16_50, 1.6 L/h
     every 0.5 m, inlet 10 m, rows 3 m apart). Prefer PC dripline or PC micro-sprinklers when a block rises more than about 2 m along
     its laterals.
   - young trees: tree_rings {area, plant_spacing_m, row_spacing_m, ring_radius_m 0.75, kind "dripline" with tape (a dripline id) or
     "drippers" with outlet (a dripper id), zone_name} rings every tree, with a lateral pipe per row, the submain and a valve picked by
     flow; tree_rings_advanced also sets the inlet head, the dripper nozzle and head, the submain side and the pipes.
   - submain "start" (the end the direction points away from: the west end for 0°, the south end for 90°), "end", or "centre" (laterals
     both ways, half as long); on a slope put it on the high side. Pass zone_name; without valve generate_block picks the smallest
     control valve whose flow range holds the block flow (ev80 3" in the orchard, ev50 2" for bananas); give valve only to force a model.
   - view_snapshot {region "drawing", colour_by "zones"} to check the blocks and what each valve feeds.
5. Network (list_entities types ["controlValve"] gives the valve positions).
   - waterSupply at the source: calc true, wl = the water level from the ground (−5 shallow well, −30 deep well, +1.5 reservoir); place it
     where the satellite picture shows the well or the reservoir.
   - Route the mainline before drawing it: preview_geometry {shapes [{kind "polyline", pts, label "main"}], base_map "satellite"} along
     the field edges and roads, and terrain_profile {pts} along it: a steady climb or fall, no local high point in the middle (or an air
     valve there).
   - Mainline pipes (scope "mainline", no spec: the design sizes them) from the supply to a tee by the blocks, branches along the field
     edge and short stubs that end exactly on each valve (the orchard: riser, branch A, branch B). Create the supply, the pipes, the
     devices on them and the controller in one create_entities call.
   - A filter on the first metres of the mainline, after the pump's place (misc spec "filter_screen80", a 3" screen, or "filter_disc50",
     a 2" disc, for drippers); a point item on a pipe splits it there.
   - Pump: create it on the mainline next to the supply (orchard: pump_c5, centrifugal, on the 5 m well; bananas: pump_sub, submersible,
     on the 30 m well, since a surface pump lifts at most about 6–7 m), or let apply_pump add the best one after the first design.
   - Controller next to the pump where there is power (type "controller" {p, st}: st ≥ valves + 1 for the pump relay; 4 in the examples);
     then, in one reply, route_wires, set_parameters {"valveClosureTimeS": 3} (solenoid valves close in seconds; the surge check uses
     it) and set_system_flows.
   - Shifts, one block each: set_system_flows mode "one_at_a_time" (first_start_hour 6, duration_hours) or "replace" with start_hour and
     duration_hours per flow (orchard 3 h then 4 h; bananas 3 h each); mode "auto" with max_flow_m3h = the source flow groups small blocks.
   - view_snapshot {region "drawing", base_map "satellite", labels "ids"} to check the supply, the valves and the zones over the image.
6. Design and check. run_design; when it reports messages, auto_fix (it designs again itself) and get_design_messages in one reply; then
   apply_fix or a change of the drawing for what is left, and run_design.
   - Pump: apply_pump (no id: the best for the duty, put on the mainline leaving the supply) and run_design in one reply; rank_pumps
     first only to compare the candidates.
   - After hand edits analyse_design; at the end optimize_design (pumps and valves); insert_air_valves on long or undulating mainlines.
   - Targets as the reports show them: zones table with every zone's p min and p max inside the allowed window and EU about 90 % or more
     (85 % on steep ground); pipes within the velocity limits (zones 1.5 m/s, mainline 2 m/s by default; ⚠ marks the rows over);
     devices table without suction or range warnings; little surplus head at the supply.
   - get_report_table "crop" gives the hours per event at the design's application rate: set the shift durations to it.
   - When a target needs a trade-off (more blocks, PC emitters, a bigger pump), ask the user.
7. Deliverables on request: get_report_table zones, bom, bomZones, electrical, crop, schedule; set_quote (markup_pct, labour_pct, tax_pct,
   freight…); export_file (dxf, dwg, report_xlsx, report_pdf, project…) and, for drawings, the sheet set: run_operation export_sheet_pdf
   {split "zones", details ["all"], include_reports true} (an overview and a sheet per block); files are always confirmed by the user.''';

// ---------------------------------------------------------------- row crops, sugarcane

const _rowCropTape = r'''Keep the to-do list with update_todo; in Plan-first mode have the plan approved with present_plan before the first change.
Tool inputs are SI as in the project file: metres, m³/s (10 m³/h = 0.00278 m³/s), metres of head; options ending in _m3h take m³/h, _m2 take m².
Catalogue ids below are the default catalogue's, as the examples use them: confirm each with search_catalog (another catalogue has other ids).
References: read_example rowCrop (four tomato blocks on thin-wall tape, two blocks per shift) and sugarcane (buried PC dripline, one per shift).

1. Brief. Read get_notes, then ask what is still missing with ask_user (2–4 options plus free text each) and record it with update_notes:
   - crop and bed or row spacing (tomato 1.8 m beds / vegetables 1.0–1.5 m / sugarcane 1.5 m or double rows / other);
   - lateral (thin-wall seasonal tape on the surface / dripline / PC dripline buried 0.2–0.4 m, subsurface drip as for sugarcane);
   - soil (sand: closer emitters / loam / clay: wider emitters), field size, roads to keep, and the slope if known;
   - water source and its flow in m³/h, water quality (surface water needs screen or disc filtration), power, hours per day, budget, brand.
2. Site. find_site, set_site; then look before drawing (pictures for you; the user's screen keeps its base map):
   - view_snapshot {region "bbox", bbox = the field with a margin, base_map "satellite"}: the field edges, roads, ditches and the source;
     view_snapshot {snapshot, pixel_bbox} zooms into a corner.
   - download_terrain (the slope decides the lateral direction and length), terrain_info, then terrain_picture {region "bbox", bbox,
     base_map "satellite"}: the contours give the direction of level laterals, colour "slope" the parts above 1–2 %; terrain_profile
     {pts} along and across the rows gives the fall each way. download_climate (ETo and rain by month).
   - Trace what you see: trace_region {snapshot, pixel [px, py] well inside a field, lawn or pond} outlines it by image analysis, far
     more exactly than by eye (check its picture; blur_m 3–6 for wide rows and orchards, tolerance when it leaks or stops short; it
     cannot split two fields of one crop with no visible limit). For the rest pick the corners on the picture: image_to_world
     {snapshot, pixels, closed true} gives the coordinates in metres, preview_geometry {shapes [{kind "polygon", pts, label}],
     base_map "satellite"} checks them over the image (nothing is created); then create them in the next step.
   If the user attached a survey or plan, import_attachment it instead and place it as its result says (a DXF or DWG keeps its own
   coordinates: set_georeference "utm" for UTM coordinates, else align_entities onto two points of the satellite picture).
3. Field and blocks.
   - The field as an area: create_entities type "area" {pts, crop, ck "crop.tomato" / "crop.vegetables" / "crop.sugarcane", pd (planting
     "MM-DD"), im "localized", wb true, eto, kc, awc, root, mad, eff, psp, rsp, wf, epp 1}. Examples: tomato eto 5.5, kc 1.1, awc 130,
     root 0.5, mad 0.4, eff 0.92, psp 0.4, rsp 1.8, wf 0.6; sugarcane eto 6, kc 1.2, awc 130, root 0.6, mad 0.6, eff 0.95, rsp 1.5, wf 0.5.
   - Create the waterSupply first (step 5), then subdivide_field {area, mode "strips", lateral "tape", tape, lateral_spacing_m,
     max_block_flow_m3h = the flow of one shift (or max_block_area_m2), road_width_m 4, direction_deg along the rows, mainline true}:
     blocks of equal area with 4 m roads (the tape ends of two blocks never touch), laterals, a submain on the supply side, a valve chosen
     by flow, and a mainline from the supply. mode "grid" with max_lateral_length_m also cuts the blocks along the rows, so no lateral is
     longer than that (about 120 m for 16 mm tape, 180 m for 20 mm PC dripline).
   - Or, as the examples, one area per block (all in one create_entities call) and generate_block on each, in one reply (rowCrop: four
     120 × 60 m blocks with 4 m roads between them; sugarcane: two 180 × 90 m blocks).
4. Laterals (search_catalog kind "tape" lists the emitter spacing, flow and head window of each).
   - rowCrop: tape16_10_30 (1.0 L/h every 0.30 m, window 4–12 m) at lateral_spacing_m 1.8 with inlet_head_m 8;
     sugarcane: drip20pc_23_75 (PC 2.3 L/h every 0.75 m, window 6–40 m) at 1.5 m with inlet_head_m 15.
   - direction_deg along the rows (0 = east, 90 = north). The examples run 120 m of 16 mm tape and 180 m of 20 mm PC dripline; for longer
     rows use submain "centre" (laterals both ways) or two areas across the rows.
   - generate_block: submain on the outer edge of each block ("start" for the west or south blocks, "end" for the east or north ones) so
     the valves line the outer roads and the trunk runs between the blocks; zone_name; the valve is picked by the block flow (ev80, 3",
     for these 13–35 m³/h blocks): give valve only to force a model.
   - On slopes above 1–2 % run the laterals level along the contours, or downhill from a submain on the high side.
   - Buried drip: update_entities depth 0.3 on the tapes, 0.6 on the submains and stubs, 0.8 on the mainline (as sugarcane; ≤ 300 per call).
   - view_snapshot {region "drawing", colour_by "zones"} to check the blocks and what each valve feeds.
5. Network (list_entities types ["controlValve"] gives the valve positions).
   - waterSupply at the reservoir (calc true, wl +1.5; a well: wl negative, the water level below the ground).
   - Trunk (scope "mainline", no spec) from the supply to a tee between the blocks, west and east branches 4 m outside the valve lines and
     a stub to each valve; with subdivide_field mainline true it is already routed. Check a route you draw first with preview_geometry
     {shapes [{kind "polyline", pts}], base_map "satellite"} and terrain_profile {pts} (no local high point, or an air valve there).
   - On its first metres (a point item on a pipe splits it there): the pump (rowCrop pump_c5, sugarcane pump_c7_5, or apply_pump after the
     first design), the screen filter (misc "filter_screen80", up to 60 m³/h) and an air valve (misc "air50", or insert_air_valves later).
   - Controller by the filter (type "controller" {p, st}: st ≥ valves + 1 for the pump relay), in the same create_entities call as the
     supply, the trunk and its devices; then, in one reply, route_wires, set_parameters {"valveClosureTimeS": 3} (solenoid valves close in
     seconds; the surge check uses it) and set_system_flows.
   - Shifts (set_system_flows): rowCrop runs two blocks per shift, a west and an east one (blocks 1 + 4, then 2 + 3, 5 h each from 06:00),
     so each shift loads both branches; sugarcane one block per shift (6 h each). Mode "auto" with max_flow_m3h = the source flow also works.
   - view_snapshot {region "drawing", base_map "satellite", labels "ids"} to check the valves and the blocks over the image.
6. Design and check. run_design; when it reports messages, auto_fix (it designs again itself) and get_design_messages in one reply;
   apply_pump (no id: the best for the duty) with run_design in one reply; optimize_design; insert_air_valves.
   - Targets: zones table with every zone inside the tape's head window and EU about 90 % or more on flat ground; pipes within the
     velocity limits (zones 1.5 m/s, mainline 2 m/s by default); the flushing table without problems; devices table without suction
     warnings; little surplus head at the supply.
   - A block short of pressure: shorter laterals, submain "centre" or a smaller block, rather than an inlet head above the tape's window.
   - get_report_table "crop" gives the hours per event (set duration_hours to it); with the climate and ck set, requirementTotals gives
     the peak gross depth per day.
7. Deliverables on request: get_report_table zones, pipes, bom, bomZones, trench, crop, schedule; set_quote; export_file, or the sheet
   set run_operation export_sheet_pdf {split "zones", details ["all"]} (always confirmed by the user).''';

// ---------------------------------------------------------------- greenhouses

const _greenhouse = r'''Keep the to-do list with update_todo; in Plan-first mode have the plan approved with present_plan before the first change.
Tool inputs are SI as in the project file: metres, m³/s (2 m³/h = 0.000556 m³/s), metres of head; options ending in _m3h take m³/h.
Catalogue ids below are the default catalogue's, as the example uses them: confirm each with search_catalog (another catalogue has other ids).
Reference: read_example greenhouse (four 9 × 50 m pepper tunnels on PC dripline, one zone per tunnel, two tunnels per shift).

1. Brief. Read get_notes, then ask what is still missing with ask_user (2–4 options plus free text each) and record it with update_notes:
   - the houses: how many, length × width and the gap between them (the example: four 9 × 50 m tunnels 2 m apart), and which way the beds run;
   - crop and row spacing (peppers or tomatoes, rows 1.5 m and plants 0.4 m / leafy vegetables / other), soil beds or substrate;
   - water: tank or cistern (its water level above the ground) / mains (pressure and flow) / well; fertigation (record it in the notes);
   - hours available, power, budget, preferred brand.
2. Site. Usually from the user's dimensions or an attached plan (import_attachment, placed on the site as its result says). With an
   address: find_site, set_site, then
   view_snapshot {region "bbox", bbox, base_map "satellite"} (a picture for you; the user's screen keeps its base map) and trace the
   houses: their corners on the picture → image_to_world {snapshot, pixels, closed true} → preview_geometry {shapes [{kind "polygon",
   pts, label}], base_map "satellite"} to check them over the image before creating them. The ground is nearly flat:
   a few spot heights are enough (terrain_info says what there is). Outdoor climate (download_climate) overstates the demand under cover: ask for the house's ETc,
   or use eto 4 mm/day as the example.
3. Houses. In one create_entities call, a closed polyline per house for the drawing (type "polyline" {pts, closed true}) and an area
   per house: type "area" {pts, crop, ck "crop.pepper" / "crop.tomato", im "localized", wb true, eto 4, kc 1.05, awc 150, root 0.3,
   mad 0.3, eff 0.95, psp 0.4, rsp 1.5, wf 0.5, epp 1}.
4. Laterals. generate_block on each house area (all in one reply): lateral "tape" with a PC dripline (search_catalog kind "tape"
   query "PC"; the example's drip16pc_16_50: 1.6 L/h every 0.5 m, window 6–40 m), inlet_head_m 15, lateral_spacing_m = row spacing
   (1.5 m; the first lateral falls half a spacing from the side wall), direction_deg along the house (90 for houses running north),
   submain "start" (the house front, by the path), valve "ev25" (1" solenoid, 0.2–6 m³/h) and zone_name = the house name.
   view_snapshot {region "drawing"} to check.
5. Network (list_entities types ["controlValve"] gives the valve positions).
   - waterSupply at the tank: calc true, wl +2 (water 2 m above the ground); from the mains instead: calc false with dh, mh, dq, mq.
   - A header (scope "mainline", no spec) from the supply along the house fronts, with a short stub to each valve (preview_geometry
     {shapes [{kind "polyline", pts}]} shows the route over the houses before you draw it).
   - On its first metres (a point item on a pipe splits it there) the pump (the example: pump_c1, 4 m³/h at 20 m; or apply_pump after
     the first design) and then a disc filter (misc "filter_disc50", 120 mesh).
   - Controller next to the pump (type "controller" {p, st}: st ≥ valves + 1 for the pump relay). The supply, the header, its devices
     and the controller go in one create_entities call; then, in one reply, route_wires, set_parameters {"valveClosureTimeS": 3}
     (solenoid valves close in seconds; the surge check uses it) and set_system_flows.
   - Shifts: two houses per shift, 1 h each from 07:00 (set_system_flows "replace" with the flows, their start_hour and duration_hours),
     or mode "auto" with max_flow_m3h = the pump flow.
   - view_snapshot {region "drawing", labels "ids"} (base_map "satellite" when georeferenced) to check the valves and the houses.
6. Design and check. run_design; when it reports messages, auto_fix (it designs again itself) and get_design_messages in one reply;
   apply_pump (about 2 m³/h for two tunnels in the example) with run_design in one reply; optimize_design.
   - Targets: zones table with every zone inside the PC window and EU about 92 % or more; pipes within the velocity limits; devices table
     without warnings; little surplus head at the pump.
   - get_report_table "crop" gives the hours per event; under cover several short pulses a day are common: ask the user, then set the flows.
7. Deliverables on request: get_report_table zones, bom, schedule; set_quote; export_file, or the sheet set run_operation
   export_sheet_pdf {split "zones"} (always confirmed by the user).''';

// ---------------------------------------------------------------- gardens and landscapes

const _landscapeSprinklers = r'''Keep the to-do list with update_todo; in Plan-first mode have the plan approved with present_plan before the first change.
Tool inputs are SI as in the project file: metres, m³/s (6 m³/h = 0.00167 m³/s), metres of head (35 m ≈ 3.4 bar); options ending in _m3h take m³/h.
Catalogue ids below are the default catalogue's, as the example uses them: confirm each with search_catalog (another catalogue has other ids).
Reference: read_example garden (a 16 × 40 m lot: sprays on the front lawn, rotors on the back lawn, dripline in two side beds, three zones).

1. Brief. Read get_notes, then ask what is still missing with ask_user (2–4 options plus free text each) and record it with update_notes:
   - what to water (lawns / shrub and flower beds / trees and pots / all) and the turf (warm-season / cool-season);
   - the connection: static pressure and the flow the service and meter give (a ¾"–1" service gives about 3–8 m³/h), whether local rules
     require a backflow preventer, or a pump and well instead. A homeowner can measure them: a pressure gauge screwed on an outdoor tap
     (taps closed: the static pressure) and the bucket test (the seconds a fully open tap takes to fill a bucket of known size:
     10 L in 20 s = 1.8 m³/h); use the smaller of that flow and what the meter allows;
   - where the controller goes (a wall with a socket), the watering window (early morning), budget, preferred brand.
2. Site. find_site, set_site, then view_snapshot {region "bbox", bbox = the lot with a margin, base_map "satellite"} (a picture for you;
   the user's screen keeps its base map; zoom with view_snapshot {snapshot, pixel_bbox}). create_vegetation_areas {bbox of the lot}
   (it analyses the satellite imagery itself; the user's base map is not changed) finds lawns and planted beds and outlines roofs,
   paving and pools to keep dry: check the result with view_snapshot {base_map "satellite", labels "ids"} and delete or edit what is wrong
   (delete_entities takes them all in one call). Trace what it missed: corners on the picture → image_to_world {snapshot, pixels,
   closed true} → preview_geometry {shapes [{kind "polygon", pts, label}], base_map "satellite"} → create_entities. On a sloping lot
   download_terrain and terrain_picture {region "bbox", bbox, base_map "satellite"} show where heads would drain. Or import_attachment
   for a plan (placed on the site as its result says), or draw from the user's dimensions.
3. Hydrozones. One area per lawn and per bed: type "area" {pts, crop, ck "crop.turf" or "crop.turfCool" for lawns, pwu "low" /
   "moderate" / "high" for beds, wb true, eto, kc 0.85 lawns / 0.6 shrubs, awc 100–110, root 0.3 lawns / 0.4 beds, mad 0.5, eff 0.75
   sprays / 0.8 rotors / 0.9 drip, im "localized" for drip beds}, and closed polylines for the house, paths and pools, all in one
   create_entities call. Never mix sprays, rotors and drip in one zone: they apply water at very different rates.
4. Supply and trunk first. waterSupply at the meter: calc false, dh = the available pressure head, mh = the maximum (static) head, dq and
   mq = the design and maximum flow in m³/s (the example: dh 35, mh 40, dq 0.00167, mq 0.00222), where the picture shows the meter. A
   mainline trunk (scope "mainline", no spec) from it along a side path, as the example (preview_geometry {shapes [{kind "polyline",
   pts}], base_map "satellite"} first, to keep it off the paving), with the water meter (misc "meter50") and the backflow preventer
   (misc "backflow50") on its first metres (a point item on a pipe splits it there): the supply, the trunk and both devices in one
   create_entities call.
5. Heads. layout_sprinklers on each lawn area (search_catalog kind "emitter" for the families and their nozzles):
   - small or narrow lawns (under about 8 m across): sprays, outlet "spray", nozzle "s12" (R 3.7 m), head_m 20;
   - larger lawns: rotors, outlet "rotor", nozzle "r3" (R 10 m), head_m 25 (the example's back lawn has them at 8 × 7 m);
   - pattern "square" (or "triangular" on wide open lawns), spacing "head_to_head", part_circles "auto" (matched half and quarter nozzles
     on edges and corners), exclusions = the house and bed outlines inside the lawn;
   - zoning true with max_zone_flow_m3h ≤ the service flow, routing true. Before each call select_entities the trunk, in the same reply
     (select_entities, layout_sprinklers, select_entities, layout_sprinklers… run in order): the zone valves go on it and no new
     mainline is drawn (without a selected mainline every call routes a new one from the supply).
   - Beds: dripline. generate_block {area: the bed, lateral "tape", tape "drip16_16_50", inlet_head_m 10, lateral_spacing_m 1.0,
     direction_deg along the bed, valve "ev25", zone_name}, then a mainline stub from the trunk to its valve. Or, as the example, one zone
     for both beds by hand: a controlValve on a stub, a zone pipe along the house front with a vertex where each dripline starts, and
     tape items from those vertices along the beds.
   - view_snapshot {region "drawing", base_map "satellite", labels "ids"} to check heads, valves and zones over the image;
     run_analysis "uniformity" gives CU, DU and the dry area of the sprinkler zones.
6. Controller and shifts. Type "controller" {p, st} on the wall where there is power (the example: 6 stations for 3 zones); then, in
   one reply, route_wires, set_parameters {"valveClosureTimeS": 3} (solenoid valves close in seconds; the surge check uses it) and the
   shifts, one zone at a time from 05:00: set_system_flows "one_at_a_time" (first_start_hour 5), or "replace" with each zone's duration
   (the example: sprays 0.5 h, rotors 0.75 h, drip 1.5 h).
7. Design and check. run_design; when it reports messages, auto_fix (it designs again itself) and get_design_messages in one reply;
   optimize_design (valve sizes).
   - Targets: each shift's flow within the supply's dq (mainline table, no ⚠) and every zone's heads inside their pressure window with
     the head available (zones table; no deficit in the mainline table); pipes within the velocity limits (1.5 m/s in zones by default);
     uniformity: aim at DU 65 % or more for sprays and 70 % for rotors, with little dry area.
   - Pressure short: fewer heads per zone (more zones), larger pipes, or a booster pump: auto_fix leaves that to you; ask the user
     before adding one (apply_fix choosePump).
   - The crop and water tables give the run times and the water budget: adjust duration_hours to them.
8. Deliverables on request: get_report_table zones, outlets, bom, electrical, schedule, water; set_quote; export_file, or the sheet set
   run_operation export_sheet_pdf {split "zones"} (the base map on screen goes under the drawing); files are always confirmed by the
   user. For a homeowner add what to buy (bom) and how long each zone runs (schedule) in plain words.''';

// ---------------------------------------------------------------- sports turf

const _sportsField = r'''Keep the to-do list with update_todo; in Plan-first mode have the plan approved with present_plan before the first change.
Tool inputs are SI as in the project file: metres, m³/s (13 m³/h = 0.00361 m³/s), metres of head (35 m ≈ 3.4 bar); options ending in _m3h take m³/h.
Catalogue ids below are the default catalogue's, as the example uses them: confirm each with search_catalog (another catalogue has other ids).
Reference: read_example sportsField (a 105 × 68 m pitch, 40 impact sprinklers on a 15 × 17 m grid, one zone per row, tank and pump).

1. Brief. Read get_notes, then ask what is still missing with ask_user (2–4 options plus free text each) and record it with update_notes:
   - the field (full-size pitch 105 × 68 m / 100 × 64 m / small-sided 60 × 40 m / another sport) and the turf (warm / cool season);
   - the heads (pop-up rotors in the field of play / impact sprinklers / heads round the pitch only);
   - water source (tank or reservoir / well / mains) and its flow, power at the pump house, the night window, budget, brand.
2. Site. find_site, set_site, then view_snapshot {region "bbox", bbox, base_map "satellite"} (a picture for you; the user's screen keeps
   its base map) to place the pitch and the pump house: the touchline corners on the picture → image_to_world {snapshot, pixels} gives
   the centre spot and the touchline direction; check the outline with preview_geometry {shapes [{kind "polygon", pts, label "pitch"}],
   base_map "satellite"}. download_terrain or spot heights (pitches fall about 0.5 % for drainage, as the example), then terrain_info
   and terrain_picture {region "bbox", bbox}; download_climate.
   If the user attached the stadium drawing, import_attachment it instead (placed on the site as its result says).
3. Turf area over the pitch and its run-off margin: create_entities type "area" {pts, crop, ck "crop.turf", wb true, eto 6, kc 0.9,
   awc 110, root 0.25, mad 0.4, eff 0.8}, unless sports_template draws it (step 4).
4. Heads (search_catalog kind "emitter"), two ways:
   - sports_template {kind "pitch", center = the centre spot, rotation_deg = the touchline direction, length_m, width_m, outlet, head_m}:
     rows along the touchlines with half circles on the touchlines and goal lines, quarter circles in the corners, matched-precipitation
     nozzles, rows and spacing from the nozzle reach. It adds no pipes: pipe it as the example. list_entities types ["outlet"] with the
     pitch bbox, group the heads by row, then one create_entities call with, per row, a controlValve 3 m beyond the goal line (zone
     "Row n", spec "ev50", 2–30 m³/h) and a zone pipe whose pts run from the valve through every head of the row in order; a mainline
     trunk 3 m beyond the valves along the goal line from the supply; and a mainline stub from the trunk to each valve.
   - Or layout_sprinklers {area: the pitch, outlet "impact34", nozzle "i5.0", head_m 35, pattern "square", spacing "head_to_head",
     part_circles "always" (impact heads turn to any arc), zoning true, max_zone_flow_m3h about 13–15, routing true}: valves, zone pipes
     and a mainline to the water supply (create the supply first).
   - The example: 8 heads every 15 m along each of 5 rows 17 m apart; i5.0 (1.9 m³/h) full, i3.5 (0.9) half and i2.5 (0.46) quarter
     circles at 35 m, riser 0 (pop-up), about 13 m³/h per inner row and 6 m³/h per touchline row. view_snapshot to check.
5. Network. waterSupply at the tank (calc true, wl +1.5), where the picture shows it; the trunk route checked with preview_geometry
   {shapes [{kind "polyline", pts}], base_map "satellite"}; on the trunk next to the supply (a point item on a pipe splits it there) the pump
   (pump_c7_5, 28 m³/h at 40 m, or apply_pump after the first design) and a check valve (misc "check100"). Controller in the pump house
   (type "controller" {p, st}: st ≥ valves + 1 for the pump relay), all in one create_entities call; then, in one reply, route_wires,
   set_parameters {"valveClosureTimeS": 3} (solenoid valves close in seconds; the surge check uses it) and the night shifts, one row at
   a time: set_system_flows "one_at_a_time" with first_start_hour 21 and duration_hours 1 (the example), or the crop table's hours per
   event. view_snapshot {region "drawing", base_map "satellite", labels "ids"} to check the rows, valves and trunk over the image.
6. Design and check. run_design; when it reports messages, auto_fix (it designs again itself) and get_design_messages in one reply;
   apply_pump with run_design in one reply; optimize_design.
   - Targets: zones table with every row inside its pressure window and the heads near the nozzles' design head; pipes within the
     velocity limits; run_analysis "uniformity": aim at CU 80 % or more and DU 70 % or more with almost no dry area. A message that a
     part circle has no matched nozzle means uneven depth at the edges: change the family or the reference nozzle.
   - Far rows short of pressure: let the design enlarge the pipes, or a stronger pump.
7. Deliverables on request: get_report_table zones, outlets, bom, electrical, schedule; set_quote; export_file, or the sheet set
   run_operation export_sheet_pdf {split "zones", details ["all"]} (always confirmed by the user).''';

// ---------------------------------------------------------------- golf

const _golfHole = r'''Keep the to-do list with update_todo; in Plan-first mode have the plan approved with present_plan before the first change.
Tool inputs are SI as in the project file: metres, m³/s (10 m³/h = 0.00278 m³/s), metres of head; options ending in _m3h take m³/h.
Catalogue ids below are the default catalogue's, as the example uses them: confirm each with search_catalog (another catalogue has other ids).
Reference: read_example golf (one hole: tee sprays, two fairway rotor zones on a triangular grid, green rotors, a pond pump, three night shifts).

1. Brief. Read get_notes, then ask what is still missing with ask_user (2–4 options plus free text each) and record it with update_notes:
   - what to water (green and approach / tees / fairway / rough too) and the drawing or aerial image of the hole;
   - turf (cool-season greens / warm-season), the head family preferred;
   - water source (pond, lake, well) and its level, an existing pump station, the night window (22:00–24:00 in the example), power, budget.
2. Site. find_site, set_site; then look before drawing (pictures for you; the user's screen keeps its base map):
   - view_snapshot {region "bbox", bbox = the hole with a margin, base_map "satellite"}: tee, fairway, green, bunkers, pond and the cart
     path; view_snapshot {snapshot, pixel_bbox} for the green and the bunker edges at full resolution.
   - download_terrain (fairways roll: elevations matter), terrain_info, then terrain_picture {region "bbox", bbox, base_map "satellite"}:
     the hollows where water collects and the high ground; download_climate.
   - Trace what you see: trace_region {snapshot, pixel [px, py] well inside a field, lawn or pond} outlines it by image analysis, far
     more exactly than by eye (check its picture; blur_m 3–6 for wide rows and orchards, tolerance when it leaks or stops short; it
     cannot split two fields of one crop with no visible limit). For the rest pick the corners on the picture: image_to_world
     {snapshot, pixels, closed true} gives the coordinates in metres, preview_geometry {shapes [{kind "polygon", pts, label}],
     base_map "satellite"} checks them over the image (nothing is created); then create them in the next step.
   Or import_attachment for the course plan (placed on the site as its result says).
3. Areas. In one create_entities call, one area each for the green, the tee and the fairway: type "area" {pts, crop, ck "crop.turf"
   or "crop.turfCool", wb true, eto 6, kc 0.9 green and tee / 0.85 fairway, awc 100, root 0.15 green / 0.2 tee / 0.25 fairway,
   mad 0.35 / 0.4 / 0.45, eff 0.8 / 0.75 / 0.75}; bunkers and the pond as closed polylines (kept dry).
4. Heads (search_catalog kind "emitter"):
   - green: sports_template {kind "green", area = the green outline, outlet "rotor", head_m 25}: part-circle rotors on a ring 1.5 m
     outside the collar, all throwing onto the green; the example has eight full-circle rotors (r3, R 10 m) on the edge of a green of 10 m radius.
   - tee: sports_template {kind "tee", center, length_m, width_m, rotation_deg along the tee, outlet "spray"}; the example has half-circle
     sprays (s12h, 20 m) every 5 m along both long sides of a 30 × 6 m tee, facing in.
   - fairway: sports_template {kind "fairway", center, length_m, width_m, rotation_deg along the centreline, outlet "rotor", head_m 25}:
     a triangular grid head to head; the example: r3 rotors 10 m apart in rows 8.66 m apart, 4 rows across 30 m.
   - The three templates go in one reply. They add no pipes or zones. Pipe them as the example: list_entities types ["outlet"] in
     each area's bbox (in one reply), then one create_entities call with a zone pipe through each row of heads (pts = the head
     positions in order), a short zone pipe joining the row ends, and per zone a controlValve 2 m outside it on a stub (green, tee, and
     every two fairway rows: about 4–15 m³/h each).
   - Or layout_sprinklers on the tee and fairway areas (pattern "triangular" for the fairway, zoning true, routing true) for the zoning and
     piping; select_entities the header just before each call, in the same reply, so the valves go on it and no new mainline is drawn.
   - view_snapshot to check the heads against the bunkers and the pond.
5. Network. waterSupply at the pond (calc true, wl −1.5), at its edge on the picture; a pump on the riser from the pond (pump_c5 in the
   example, or apply_pump after the first design) to a header (scope "mainline", no spec) along the cart path with a stub to each valve
   (preview_geometry {shapes [{kind "polyline", pts}], base_map "satellite"} and terrain_profile {pts} along the route first: the high
   points get an air valve); view_snapshot {region "drawing", base_map "satellite", labels "ids"} to check; valves ev25 (green, tee) and
   ev40 (fairway zones). Controller by the pump house (type "controller" {p, st}: 6 stations in the example), in the create_entities call
   of the supply, pump and header; then, in one reply, route_wires, set_parameters {"valveClosureTimeS": 3} (solenoid valves close in
   seconds; the surge check uses it) and the shifts (set_system_flows "replace"): green + tee for 0.5 h from 22:00, then fairway zone 1
   and fairway zone 2 for 0.75 h each.
6. Design and check. run_design; when it reports messages, auto_fix (it designs again itself) and get_design_messages in one reply;
   apply_pump with run_design in one reply; optimize_design; insert_air_valves when the header runs over rolling ground.
   - Targets: zones table with every zone inside its pressure window; pipes within the velocity limits; run_analysis "uniformity" by
     area: aim at DU 70 % or more on greens and tees, with no dry patches on the putting surface; little surplus head at the pump.
7. Deliverables on request: get_report_table zones, outlets, bom, electrical, schedule; set_quote; export_file, or the sheet set
   run_operation export_sheet_pdf {split "areas", details ["all"]} (always confirmed by the user).''';

// ---------------------------------------------------------------- centre pivots

const _centrePivot = r'''Keep the to-do list with update_todo; in Plan-first mode have the plan approved with present_plan before the first change.
Tool inputs are SI as in the project file: metres, m³/s (12 m³/h = 0.00333 m³/s), metres of head; options ending in _m3h take m³/h.
Catalogue ids below are the default catalogue's, as the examples use them: confirm each with search_catalog (another catalogue has other ids).
References: read_example pivot (300 m full circle on maize, deep well with a submersible pump) and sectorPivot (250 m, a 270° sector with an end gun, pond pump).

1. Brief. Read get_notes, then ask what is still missing with ask_user (2–4 options plus free text each) and record it with update_notes:
   - the field outline and what must stay dry (farmstead, roads, power lines, trees); full circle or sector; end gun (yes / no);
   - crop and its peak demand (maize / soybean / wheat / other: ETo and Kc), soil intake (sand / loam / clay limits the application rate);
   - hours per revolution (24 h is common), span length (50–56 m), the machine and tower prices if the bill of materials should cost them;
   - water source: well (water level, yield in m³/h) / pond or canal (water level) and its distance; power at the pivot point; budget; brand.
2. Site. find_site, set_site, then view_snapshot {region "bbox", bbox = the field with a margin, base_map "satellite"} (a picture for
   you; the user's screen keeps its base map) to trace the field, the obstacles (farmstead, power lines, trees) and the source: corners
   on the picture → image_to_world {snapshot, pixels, closed true} → preview_geometry {shapes [{kind "polygon", pts, label}], base_map
   "satellite"} to check them over the image → create_entities (step 3). Or import_attachment of a KML or SHP of the field (placed by
   its coordinate system; a DXF or DWG is placed as the import result says). download_terrain and download_climate in one reply (spot
   heights and downloaded terrain are no pivot obstacle; fit_pivot keeps 10 m from the symbols inside the field, such as trees and
   posts), then terrain_info and terrain_picture {region "bbox", bbox, base_map "satellite", colour "slope"} (towers climb at most
   about 15 %).
3. Field. In one create_entities call, one area: type "area" {pts, crop, ck "crop.maize" / "crop.soybean", pd (planting "MM-DD"),
   wb true, eto, kc, awc 120, root 0.5–0.6, mad 0.5, eff 0.85}, and the obstacles as closed polylines or circles inside it.
   fit_pivot keeps clear of every closed shape inside or across the field; a shape that holds the whole field (a property line, a
   second outline or a hatch of the same field) is no obstacle. When no machine fits, its message names the shapes in the way:
   delete or move the ones that are no real obstacle, or run_operation fit_pivot_advanced {area, obstacles [the real ones]}.
4. Machine.
   - fit_pivot {area, sector true to allow a part circle, end_throw_m 5–8}: the largest pivot with standard spans. Or create_entities
     type "pivot" {p (centre), r (radius to the last sprinkler), kind "pivot", span, ang, sector, depth, hours, hend, throw, ssp, zone,
     cost} like the examples: r 300, span 50, depth 8.5, hours 24, hend 14, throw 8, ssp 2.5; the sector example has r 250, sector 270
     and ang 135 (ang = the middle of the sector, degrees counter-clockwise from east), leaving the farmstead quadrant dry.
   - Gross depth per revolution: depth ≥ peak ETc / efficiency × hours / 24, with a margin for stops (maize 6 × 1.15 / 0.85 = 8.1 → 8.5 mm);
     with the climate and ck set, get_report_table requirementTotals gives the peak gross depth per day.
   - End gun: update_entities on the pivot with qg (m³/s: 12 m³/h = 0.00333) and hg (30 m in the sector example).
   - The irrigated area reaches r + throw: make the area that circle or sector if it was drawn smaller. view_snapshot to check.
5. Water and mainline (no zone valve: the pivot is the demand, and one machine needs no system flows).
   - waterSupply at the source: calc true, wl −25 for the example's well (water deeper than about 6–7 m needs a submersible pump:
     pump_s30 there), −1.5 for the pond (a surface pump: pump_c20 for 64 m³/h at about 45 m).
   - The well column (supply → pump → gate valve, misc "gate100") as a pipe of its own, then the adductor (scope "mainline", no spec)
     from the gate to the pivot centre, ending exactly on p. Route it first with preview_geometry {shapes [{kind "polyline", pts}],
     base_map "satellite"} along roads and field edges, and terrain_profile {pts}: the lift to the pivot point and the high points that
     need an air valve. Or draw the pipes without the pump and let apply_pump add it after the first
     design.
   - set_parameters {"valveClosureTimeS": 3} (the surge check uses it). view_snapshot {region "drawing", base_map "satellite",
     labels "ids"} to check the machine, the source and the adductor over the image.
6. Design and check. run_design; when it reports messages, auto_fix (it designs again itself) and get_design_messages in one reply;
   get_report_table pivots, pivotSpans and pivotPackage in one reply (inlet pressure, end pressure, nozzles by span); apply_pump with
   run_design in one reply; optimize_design.
   - run_analysis "transients": the sector example fixes the adductor at pvc150 (update_entities spec "pvc150", auto false) because the
     cheaper DN 125 surges past its PN 80 class on a stop; suggest_air_valves, then insert_air_valves, on the adductor.
   - Targets: the pivot's inlet pressure met with little surplus head at the pump (a 30 hp pump would leave 19 m of surplus in the
     sector example), end pressure ≥ hend, mainline velocity within 2 m/s (1.1 m/s in the sector example), no pivot warning about the
     application rate against the soil intake.
7. Deliverables on request: get_report_table pivots, pivotSpans, pivotPackage, pivotTimer, pivotElectrical, bom; set_quote;
   export_file, or the sheet set run_operation export_sheet_pdf {details ["all"], charts true} (always confirmed by the user).''';

// ---------------------------------------------------------------- linear moves

const _linearMove = r'''Keep the to-do list with update_todo; in Plan-first mode have the plan approved with present_plan before the first change.
Tool inputs are SI as in the project file: metres, m³/s (100 m³/h = 0.0278 m³/s), metres of head; options ending in _m3h take m³/h.
Catalogue ids below are the default catalogue's, as the example uses them: confirm each with search_catalog (another catalogue has other ids).
Reference: read_example linear (a 392 m machine on wheat travelling 800 m along a canal, a 30 hp pump and a check valve at the inlet end).

1. Brief. Read get_notes, then ask what is still missing with ask_user (2–4 options plus free text each) and record it with update_notes:
   - the field (width across the machine and length of travel; the example 400 × 800 m) and how flat it is along the travel;
   - the feed (canal or ditch beside the travel / hose from a hydrant / mainline at the inlet end) and its water level;
   - crop and peak demand (wheat / maize / vegetables / other: ETo and Kc), soil intake, hours per pass, span length (50–60 m);
   - power, the machine price for the bill of materials, budget, brand.
2. Site. find_site, set_site, then view_snapshot {region "bbox", bbox = the field with a margin, base_map "satellite"} (a picture for
   you; the user's screen keeps its base map) to trace the field and the canal: corners on the picture → image_to_world {snapshot,
   pixels, closed true} → preview_geometry {shapes [{kind "polygon", pts, label}], base_map "satellite"} → create_entities (or
   import_attachment, placed as its result says). download_terrain and download_climate in one reply, terrain_info, then
   terrain_profile {pts} along both edges of the travel and terrain_picture {region "bbox", bbox, colour "slope"} (a linear needs an
   even, nearly flat field).
3. Field. One rectangular area: create_entities type "area" {pts, crop, ck "crop.wheat", wb true, eto 5.5, kc 1.15, awc 120, root 0.8,
   mad 0.55, eff 0.85}. fit_pivot does not place linears.
4. Machine. create_entities type "pivot" {kind "linear", p = the inlet end of the machine at a corner of the field, ang = the direction
   the machine reaches from p (degrees counter-clockwise from east), r = the machine length to the last sprinkler (392 m; the irrigated
   width is r + throw), travel = the length of travel, to the left of ang (800 m: north when ang is 0), span 56, depth 8 (gross mm per
   pass), hours 24, hend 14, throw 8, ssp 2.5, zone, cost}. view_snapshot to check that the rectangle covers the field.
   - depth ≥ peak ETc / efficiency × hours / 24 (wheat 5.5 × 1.15 / 0.85 = 7.4 → 8 mm); the machine flow is about area × depth / hours
     (32 ha × 8 mm / 24 h ≈ 107 m³/h).
5. Water. waterSupply at the intake (calc true, wl −2 for the canal level); a short mainline (scope "mainline", no spec) from it through
   the pump (pump_big, 120 m³/h at 55 m in the example, or apply_pump after the first design) and a check valve (misc "check100") to p;
   a point item on a pipe splits it there. set_parameters {"valveClosureTimeS": 3} (the surge check uses it). The program feeds the
   machine at p, the start of the travel; no system flows are needed for one machine. view_snapshot {region "drawing", base_map
   "satellite", labels "ids"} to check the machine, the intake and the pipe over the image.
6. Design and check. run_design; when it reports messages, auto_fix (it designs again itself) and get_design_messages in one reply;
   get_report_table pivots and pivotSpans; apply_pump with run_design in one reply; run_analysis "transients"; optimize_design.
   - Targets: the inlet pressure met with little surplus head at the pump, end pressure ≥ hend, mainline velocity within the limit
     (2 m/s by default), no warning about the application rate against the soil intake.
7. Deliverables on request: get_report_table pivots, pivotSpans, pivotPackage, pivotTimer, pivotElectrical, bom; set_quote; export_file,
   or the sheet set run_operation export_sheet_pdf {details ["all"], charts true} (always confirmed by the user).''';

// ---------------------------------------------------------------- gravity-fed drip

const _gravityDrip = r'''Keep the to-do list with update_todo; in Plan-first mode have the plan approved with present_plan before the first change.
Tool inputs are SI as in the project file: metres, m³/s (10 m³/h = 0.00278 m³/s), metres of head (1 m of fall gives 1 m of head); options ending in _m3h take m³/h.
Catalogue ids below are the default catalogue's, as the example uses them: confirm each with search_catalog (another catalogue has other ids).
Reference: read_example gravity (a hilltop reservoir 45 m above two vegetable blocks on dripline; gate valve, PRV and disc filter, no pump).

1. Brief. Read get_notes, then ask what is still missing with ask_user (2–4 options plus free text each) and record it with update_notes:
   - the source (reservoir / tank on a stand / spring box / canal intake), its position, its water level and its volume or inflow;
   - the field, crop and row spacing (vegetables 1.5 m rows / orchard / other), soil;
   - the route of the line down the slope, hours per day, whether there is power for a controller (or battery controllers), budget.
2. Site. find_site, set_site, then view_snapshot {region "bbox", bbox = the reservoir and the field, base_map "satellite"} (a picture
   for you; the user's screen keeps its base map). download_terrain is essential, the head is the elevation difference: terrain_info
   (is the slope between the reservoir and the field covered by data?), terrain_picture {region "bbox", bbox, base_map "satellite"} for
   the relief, and terrain_profile {pts from the reservoir to the field} for the fall (the example falls 45 m over 225 m, then 0.5 %
   across the field). download_climate for the requirement. Or import_attachment for a survey (placed on the site as its result says).
   - Trace what you see: trace_region {snapshot, pixel [px, py] well inside a field, lawn or pond} outlines it by image analysis, far
     more exactly than by eye (check its picture; blur_m 3–6 for wide rows and orchards, tolerance when it leaks or stops short; it
     cannot split two fields of one crop with no visible limit). For the rest pick the corners on the picture: image_to_world
     {snapshot, pixels, closed true} gives the coordinates in metres, preview_geometry {shapes [{kind "polygon", pts, label}],
     base_map "satellite"} checks them over the image (nothing is created); then create them in the next step.
3. Blocks. One area per block, in one create_entities call: type "area" {pts, crop, ck "crop.vegetables", im "localized", wb true,
   eto 5, kc 1.05, awc 120, root 0.4, mad 0.45, eff 0.9, psp 0.3, rsp 1.5, wf 0.5, epp 2}; the example has two 100 × 60 m blocks with a
   4 m road between.
4. Laterals. generate_block on each block (in one reply): lateral "tape", tape "drip16_16_50" (1.6 L/h every 0.5 m, window 5–25 m),
   inlet_head_m 10, lateral_spacing_m 1.5, direction_deg along the field's contours (level laterals; 0 in the example), submain on the
   outer edge ("start" for the west block, "end" for the east one), valve "ev40" (1½", 1–16 m³/h) and zone_name. With little head at
   the valves (under about 10 m) keep the laterals short and check the window after the design. view_snapshot {region "drawing"} to
   check.
5. Network without a pump (list_entities types ["controlValve"] gives the valve positions).
   - waterSupply at the reservoir: calc true, wl = the water level above the ground there (+2 in the example).
   - Route the line down first: preview_geometry {shapes [{kind "polyline", pts}], base_map "satellite"} and terrain_profile {pts}: a
     steady descent, around the local high points (or an air valve on each), the static head at the foot.
   - Mainline (scope "mainline", no spec) from the supply down the slope to a tee between the blocks, branches 4 m outside the valve
     lines and a stub to each valve. On it (a point item on a pipe splits it there): a gate valve at the outlet (misc "gate50"); near the
     field a pressure reducing valve (misc "prv50" with set 25, the head it keeps downstream) where the static head would exceed what the
     zones and pipes take; and a disc filter after it (misc "filter_disc50").
   - Controller by the filter (type "controller" {p, st}: st ≥ valves), in the create_entities call of the supply, the line and its
     devices; then, in one reply, route_wires, set_parameters {"valveClosureTimeS": 3} (solenoid valves close in seconds; the surge
     check uses it) and the shifts: one block at a time, 3 h each from 06:00 (set_system_flows "one_at_a_time" with first_start_hour 6
     and duration_hours 3).
   - view_snapshot {region "drawing", base_map "satellite", labels "ids"} to check the line, the devices and the valves over the image.
6. Design and check. run_design; when it reports messages, auto_fix (it designs again itself) and get_design_messages in one reply;
   optimize_design {choose_pumps false}.
   - The supply in the summary and the mainline table: a need of 0 with a surplus means gravity is enough; a positive need means the
     reservoir is too low for this layout (larger pipes, fewer zones per shift, shorter laterals, or a pump: ask the user).
   - Devices table: the PRV's inlet above its setting in every shift. Zones table: every zone inside the 5–25 m window, EU about 90 %.
   - The line down the slope: pipes table pressures within the pipe class (45 m of static head below the reservoir in the example);
     run_analysis "transients" (a valve closing at the foot of a long fall); suggest_air_valves, then insert_air_valves, at the high
     points and along the descent.
7. Deliverables on request: get_report_table zones, pipes, devices, bom, crop; set_quote; export_file, or the sheet set run_operation
   export_sheet_pdf {split "zones", details ["all"], charts true} (always confirmed by the user).''';

// ---------------------------------------------------------------- nurseries

const _nursery = r'''Keep the to-do list with update_todo; in Plan-first mode have the plan approved with present_plan before the first change.
Tool inputs are SI as in the project file: metres, m³/s (2.5 m³/h = 0.000694 m³/s), metres of head; options ending in _m3h take m³/h.
Catalogue ids below are the default catalogue's, as the example uses them: confirm each with search_catalog (another catalogue has other ids).
Reference: read_example nursery (three 12 × 48 m beds under micro-sprinklers on a 4 × 4 m grid, an elevated tank, a small pump, a disc filter).

1. Brief. Read get_notes, then ask what is still missing with ask_user (2–4 options plus free text each) and record it with update_notes:
   - the beds (number and size; the example three 12 × 48 m beds 4 m apart) and the plants (containers / seedlings and cuttings / other);
   - overhead micro-sprinklers (the example) or a dripper per container (another layout: ask);
   - water source (elevated tank / mains / well) and its quality (micro nozzles clog: filtration), power, cycles per day, budget, brand.
2. Site. find_site, set_site and view_snapshot {region "bbox", bbox, base_map "satellite"} (a picture for you; the user's screen keeps
   its base map), or the user's dimensions or plan (import_attachment, placed as its result says). Trace the beds from the picture:
   corners → image_to_world {snapshot, pixels, closed true} → preview_geometry {shapes [{kind "polygon", pts, label}], base_map
   "satellite"} → create_entities.
   The yard is nearly flat: a few spot heights (terrain_info says what there is); download_climate for the requirement.
3. Beds. In one create_entities call, a closed polyline per bed for the drawing (type "polyline" {pts, closed true}) and an area per
   bed: type "area" {pts, crop, wb true, eto 5, kc 1.0, awc 100, root 0.2, mad 0.3, eff 0.8}.
4. Heads. generate_block on each bed (in one reply): lateral "sprayline", outlet "micro" (micro-sprinkler 360°), nozzle "m70" (70 L/h,
   R 4 m), head_m 15, emitter_spacing_m 4 and lateral_spacing_m 4 (a 4 × 4 m square; the first lateral falls half a spacing in from
   the bed edge and the first head half a spacing from the submain), direction_deg along the bed (90 for beds running north), submain
   "start", valve "ev25" (1", 0.2–6 m³/h) and zone_name = the bed. That grid applies about 4.4 mm/h; check run_analysis "uniformity"
   (CU, DU, dry area) and tighten the grid or change the nozzle when it is poor. view_snapshot {region "drawing"} to check.
5. Network (list_entities types ["controlValve"] gives the valve positions). waterSupply at the tank (calc true, wl +2.5 for an elevated
   tank), where the picture shows it; a header (scope "mainline", no spec) along the bed fronts with a stub to each valve (preview_geometry
   {shapes [{kind "polyline", pts}]} first; view_snapshot {region "drawing", labels "ids"} to check); on its first metres (a point item on a pipe
   splits it there) the pump (pump_c1 in the example, or apply_pump after the first design) and a disc filter (misc "filter_disc50").
   Controller by the pump (type "controller" {p, st}: st ≥ valves + 1 for the pump relay), with the supply, the header and its devices in
   one create_entities call; then, in one reply, route_wires, set_parameters {"valveClosureTimeS": 3} (solenoid valves close in seconds;
   the surge check uses it) and the shifts: one bed at a time, 1.5 h each from 06:00 (set_system_flows "one_at_a_time",
   first_start_hour 6, duration_hours 1.5): the example's programme asks 1.43 h (6.25 mm gross at 4.4 mm/h).
6. Design and check. run_design; when it reports messages, auto_fix (it designs again itself) and get_design_messages in one reply;
   apply_pump with run_design in one reply; optimize_design.
   - Targets: zones table with every zone inside the nozzle's pressure window; pipes within the velocity limits; CU and DU as
     run_analysis "uniformity" reports them; little surplus head at the pump.
   - get_report_table "crop" gives the hours per event: set duration_hours to it (split it into several short cycles if the user wants).
7. Deliverables on request: get_report_table zones, outlets, bom, schedule; set_quote; export_file, or the sheet set run_operation
   export_sheet_pdf {split "zones"} (always confirmed by the user).''';

// ---------------------------------------------------------------- pastures

const _pasture = r'''Keep the to-do list with update_todo; in Plan-first mode have the plan approved with present_plan before the first change.
Tool inputs are SI as in the project file: metres, m³/s (30 m³/h = 0.00833 m³/s), metres of head (30 m ≈ 2.9 bar); options ending in _m3h take m³/h.
Catalogue ids below are the default catalogue's, as the example uses them: confirm each with search_catalog (another catalogue has other ids).
Reference: read_example pasture (three 72 × 72 m paddocks, impact sprinklers on a 12 × 18 m grid, one paddock per night shift).

1. Brief. Read get_notes, then ask what is still missing with ask_user (2–4 options plus free text each) and record it with update_notes:
   - the paddocks (number and size; the example three 72 × 72 m paddocks with 6 m lanes) and the grazing rotation (one paddock a night?);
   - forage (grass pasture / alfalfa / other), soil intake (sand / loam / clay), wind (strong wind needs a closer spacing);
   - fixed buried lines or movable ones; water source (reservoir / well / canal) and its flow; power; the night window; budget; brand.
2. Site. find_site, set_site; then look before drawing (pictures for you; the user's screen keeps its base map):
   - view_snapshot {region "bbox", bbox = the paddocks with a margin, base_map "satellite"}: fences, lanes, the gate and the source.
   - download_terrain, terrain_info, then terrain_picture {region "bbox", bbox, base_map "satellite"}; download_climate.
   - Trace what you see: trace_region {snapshot, pixel [px, py] well inside a field, lawn or pond} outlines it by image analysis, far
     more exactly than by eye (check its picture; blur_m 3–6 for wide rows and orchards, tolerance when it leaks or stops short; it
     cannot split two fields of one crop with no visible limit). For the rest pick the corners on the picture: image_to_world
     {snapshot, pixels, closed true} gives the coordinates in metres, preview_geometry {shapes [{kind "polygon", pts, label}],
     base_map "satellite"} checks them over the image (nothing is created); then create them in the next step.
   Or import_attachment for the farm plan (placed on the site as its result says).
3. Paddocks. One area each, in one create_entities call: type "area" {pts, crop, ck "crop.pasture" or "crop.alfalfa", wb true, eto 5,
   kc 0.85, awc 110, root 0.5, mad 0.55, eff 0.75}.
4. Spray lines. generate_block on each paddock (in one reply): lateral "sprayline", outlet "impact34" (impact sprinkler ¾"), nozzle
   "i4.0" (1.2 m³/h, R 13 m at 30 m), head_m 30, emitter_spacing_m 12, lateral_spacing_m 18 (a 12 × 18 m grid; the first lateral
   9 m inside the fence), direction_deg 0 (along the paddock), submain "start", valve "ev80" (3", 5–80 m³/h) and zone_name = the
   paddock. That gives 24 heads, about 29 m³/h and 5.6 mm/h per paddock, below the intake of most soils. The design sizes the lateral
   pipes; the example fixes them at pvc50 (update_entities spec "pvc50", auto false on the spraylines). view_snapshot {region "drawing"}
   to check.
5. Network (list_entities types ["controlValve"] gives the valve positions). waterSupply at the reservoir (calc true, wl +1.5), where the
   picture shows it; a mainline (scope "mainline", no spec) along the lane south of the paddocks with a stub north to each valve (route it
   first with preview_geometry {shapes [{kind "polyline", pts}], base_map "satellite"} and terrain_profile {pts}: no local high point, or an
   air valve there; check with view_snapshot {region "drawing", base_map "satellite", labels "ids"}); on it next to the supply (a point item
   on a pipe splits it there) the pump (pump_c7_5, 28 m³/h at 40 m, or apply_pump after the first design) and a check valve
   (misc "check100"). Controller by the pump (type "controller" {p, st}: st ≥ valves + 1 for the pump relay), all in one
   create_entities call; then, in one reply, route_wires, set_parameters {"valveClosureTimeS": 3} (solenoid valves close in seconds;
   the surge check uses it) and the shifts: one paddock per night, 2 h each from 20:00 (set_system_flows "one_at_a_time",
   first_start_hour 20, duration_hours 2), or the crop table's hours per event.
6. Design and check. run_design; when it reports messages, auto_fix (it designs again itself) and get_design_messages in one reply;
   apply_pump with run_design in one reply; optimize_design; insert_air_valves on long mainlines.
   - Targets: zones table with every zone inside the nozzle's pressure window (the far sprinklers near 30 m); pipes within the velocity
     limits; run_analysis "uniformity": aim at CU 75–80 % or more; little surplus head at the pump.
7. Deliverables on request: get_report_table zones, outlets, bom, electrical, crop, schedule; set_quote; export_file, or the sheet set
   run_operation export_sheet_pdf {split "zones"} (always confirmed by the user).''';

// ---------------------------------------------------------------- perennials on contour lines

const _coffeeContours = r'''Keep the to-do list with update_todo; in Plan-first mode have the plan approved with present_plan before the first change.
Tool inputs are SI as in the project file: metres, m³/s (10 m³/h = 0.00278 m³/s), metres of head (1 m of elevation = 1 m of head); options ending in _m3h take m³/h.
Catalogue ids below are the default catalogue's, as the example uses them: confirm each with search_catalog (another catalogue has other ids).
Reference: read_example coffee (three blocks on a 7 % hillside whose laterals follow the contours, PC dripline, a well and pump at the foot).

1. Brief. Read get_notes, then ask what is still missing with ask_user (2–4 options plus free text each) and record it with update_notes:
   - crop and spacing (coffee 3.5 × 0.7 m / tea / citrus / other) and whether the rows are planted on the contour or up and down the slope;
   - the terrain data (a survey with contours / downloaded elevation data) and the slope (under 5 % / 5–15 % / steeper);
   - water source at the foot or at the top of the hill (well water level / reservoir / spring) and its flow, power, hours per day, budget,
     brand.
2. Site. find_site, set_site, then view_snapshot {region "bbox", bbox = the field with a margin, base_map "satellite"} (a picture for
   you; the user's screen keeps its base map) to see the field and the rows. Terrain is essential: import_attachment of the survey with
   its contours (placed on the site as its result says), or download_terrain; terrain_info (how dense the data are, where they are
   thin); terrain_picture {region "bbox", bbox, base_map "satellite", interval_m 2} shows the contours over the image (colour "slope"
   for the slope classes); terrain_profile {pts up the slope} measures it; list_entities types ["contour"] gives the contour polylines
   (their vertices give the row direction). download_climate for the requirement.
   - Trace what you see: trace_region {snapshot, pixel [px, py] well inside a field, lawn or pond} outlines it by image analysis, far
     more exactly than by eye (check its picture; blur_m 3–6 for wide rows and orchards, tolerance when it leaks or stops short; it
     cannot split two fields of one crop with no visible limit). For the rest pick the corners on the picture: image_to_world
     {snapshot, pixels, closed true} gives the coordinates in metres, preview_geometry {shapes [{kind "polygon", pts, label}],
     base_map "satellite"} checks them over the image (nothing is created); then create them in the next step.
3. Blocks. Bands along the slope, each between two contour lines (the example: three bands 150 m long and 60 m wide with 4 m roads
   between them), one area each, in one create_entities call: type "area" {pts, crop, ck "crop.coffee", im "localized", wb true,
   eto 4.5, kc 0.95, awc 120, root 0.8, mad 0.5, eff 0.92, psp 0.7, rsp 3.5, wf 0.4, epp 1}. Narrow bands keep each block's elevation
   range small.
4. Laterals. Level laterals along the contours keep the pressure even; the submain takes the elevation change, running up the slope at
   one end of the block.
   - generate_block on each block, in one reply {area, lateral "tape", tape "drip16pc_16_50" (PC 1.6 L/h every 0.5 m, window
     6–40 m), inlet_head_m 15, lateral_spacing_m 3.5, guide = the contour (or a polyline along the block's lower edge) drawn a few
     metres past the block's ends, submain "start" or "end" (the end nearest the mainline), valve "ev40" (1½", 1–16 m³/h),
     valve_position "centre", stub_m 2, zone_name}: the laterals are offset copies of the guide every 3.5 m, as in the example. Keep
     each band narrower than the radius of the contour's bends, and cut it into shorter blocks (each with its own generate_block and
     valve) where they bend more.
   - Check the result with view_snapshot {labels "ids"}.
   - PC dripline is the rule on hillsides: laterals that do not stay quite level still deliver the same flow.
5. Network (list_entities types ["controlValve"] gives the valve positions).
   - waterSupply at the source at the foot of the slope: calc true (the example's well: wl −5, within a surface pump's suction lift).
   - Route the mainline first: preview_geometry {shapes [{kind "polyline", pts}], base_map "satellite"} and terrain_profile {pts}: a
     steady climb, no hump where air would gather (or an air valve there), the lift to the top block.
   - The mainline (scope "mainline", no spec) climbs one side of the blocks (the west side in the example) with a stub to each valve; on
     its first metres (a point item on a pipe splits it there) the pump (pump_c7_5 in the example, or apply_pump after the first design)
     and a screen filter (misc "filter_screen80").
   - Controller in the pump house (type "controller" {p, st}: st ≥ valves + 1 for the pump relay), with the supply, the mainline and its
     devices in one create_entities call; then, in one reply, route_wires, set_parameters {"valveClosureTimeS": 3} (solenoid valves close
     in seconds; the surge check uses it) and the shifts (set_system_flows "replace"): the example runs blocks 1 + 2 together for 4 h
     from 06:00, then block 3 for 4 h.
   - view_snapshot {region "drawing", base_map "satellite", labels "ids"} to check the valves and the blocks over the image.
6. Design and check. run_design; when it reports messages, auto_fix (it designs again itself) and get_design_messages in one reply;
   apply_pump with run_design in one reply; optimize_design.
   - Targets: zones table with every zone inside the PC window (from its lowest to its highest lateral) and EU about 90 % or more; the
     pump lifts the static head to the top block plus that block's need (mainline table); pipes within the velocity limits.
   - The mainline up the hill: suggest_air_valves, then insert_air_valves, at the high points; run_analysis "transients" and the pipes
     and surge tables within the pipe class at the foot of the slope.
   - A block whose valve sees more head than its window takes: a pressure reducing valve before that valve (misc with a PRV id from
     search_catalog kind "valve", set = the head to keep), or a narrower band; ask the user.
7. Deliverables on request: get_report_table zones, pipes, bom, bomZones, crop; set_quote; export_file, or the sheet set run_operation
   export_sheet_pdf {split "zones", charts true} (always confirmed by the user).''';
