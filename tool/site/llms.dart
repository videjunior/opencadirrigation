part of '../site.dart';

// llms.txt (the llmstxt.org proposal) and llms-full.txt: what a language
// model needs to describe OpenCADIrrigation correctly, in Markdown and
// without the application shell. English, the canonical language of the
// project, with links to the page of every other language. The page texts
// come from `_en`; the technical facts below follow the manual (docs/manual/), so update both
// when the app changes (and keep to the editorial rules: no competing
// products).

/// Short facts, as `(label, value)`, shared by both files.
List<(String, String)> _facts() => [
  (
    'What',
    'Browser-based CAD for designing pressurised irrigation systems (drip, micro-sprinkler, sprinkler, valve-in-head, centre pivot, linear move and travelling gun) and surface irrigation, with a hydraulic engine, automatic layout and pipe sizing, transient analysis, bill of materials, quotes and reports, and an optional AI assistant (Claude, GPT, Gemini, Grok, Muse or any model of OpenRouter, with the user\'s own key) that draws and designs the project with the program\'s own tools',
  ),
  (
    'Price',
    'Free for professional, academic and personal use; no account or sign-up. The optional AI assistant runs on the user\'s own account with Anthropic, OpenAI, Google, xAI, Meta or OpenRouter, which that company bills; Google\'s Gemini Flash models and some of OpenRouter\'s models can be used free of charge within limits',
  ),
  ('Licence', 'Open source under the MIT licence; source code (Dart and Flutter) at $appRepositoryUrl'),
  ('Runs in', 'Chrome, Edge, Firefox and Safari on desktop, tablet and phone; installable as a PWA; starts without a network after the first visit; light and dark themes; nothing to download'),
  (
    'Privacy',
    'Projects stay on the user\'s computer (browser storage and `.oci.json` files); OpenCADIrrigation runs no server and has no accounts. A share link carries the project inside the address. The optional AI assistant sends nothing until the user presses Send, and then only to the provider the user chose, with the user\'s own key; its voice dictation, when used, goes through the browser\'s own speech recognition (the browser maker\'s service), and saved conversations stay in that browser. The fonts of every script and symbol come from the site itself; the site and the app count visits with Google Analytics, which uses cookies (Cookie settings at the foot of the pages turns it off). Privacy policy: ${siteUrl}privacy/; terms of use: ${siteUrl}terms/',
  ),
  ('Languages', '${siteLanguages.length}: ${[for (final l in siteLanguages) _englishNames[l.code]].join(', ')}'),
  ('Project file', '`.oci.json`, readable JSON that holds the drawing, the catalogue, the parameters and the last results'),
  (
    'CAD, GIS and survey exchange',
    'Import DXF, DWG, DGN V7, PDF plans, KML/KMZ, shapefile, GeoJSON, GPX, LandXML, LAS, EPANET .inp, CSV/XYZ survey points, GeoTIFF and images; export DXF 2000 with native entities or R12, DWG 2000, PDF, PNG, SVG, KML/KMZ, GeoJSON, shapefile, GPX, LandXML, EPANET .inp and IFC 4',
  ),
  ('Reports', 'PDF in any of the 20 languages, Excel (XLSX), CSV and TXT'),
  (
    'AI assistant',
    'Optional: a model of Anthropic (Claude), OpenAI (GPT), Google (Gemini), xAI (Grok), Meta (Muse) or, through OpenRouter, of hundreds of others, with the user\'s own API key, called from the browser with no server in between; it reads the project, looks at the satellite image and the terrain, outlines fields on the imagery, follows the points the user marks on the map and, with the program\'s own tools, lays out sprinklers and drip, divides fields, routes pipes and valves, runs the design, fixes warnings, optimises, reviews the design, checks drawing sheets before export and writes the report; every change waits for the user\'s approval (or applies automatically) and can be undone; another model can give a second opinion on an answer; open it at $siteUrl?ai=1',
  ),
  (
    'Command line and API',
    '`bin/oci.dart` designs, analyses, checks and exports `.oci.json` projects and lists their materials; the engine is a documented Dart library ([docs/API.md]($appRepositoryUrl/blob/main/docs/API.md)) and an MCP server for other AI applications ([docs/MCP.md]($appRepositoryUrl/blob/main/docs/MCP.md))',
  ),
  ('Version', '$appVersion, updated $siteLastMod'),
  ('Site', siteUrl),
];

/// Language names in English, for the file that is written in English.
const _englishNames = {
  'id': 'Indonesian',
  'de': 'German',
  'en': 'English',
  'es': 'Spanish',
  'fr': 'French',
  'ha': 'Hausa',
  'sw': 'Swahili',
  'pt': 'Portuguese',
  'vi': 'Vietnamese',
  'tr': 'Turkish',
  'ru': 'Russian',
  'ar': 'Arabic',
  'ur': 'Urdu',
  'hi': 'Hindi',
  'mr': 'Marathi',
  'bn': 'Bengali',
  'pa': 'Punjabi',
  'te': 'Telugu',
  'zh': 'Chinese',
  'ja': 'Japanese',
};

/// "Deutsch (German)"; just "English" or "Hausa" when both names agree.
String _bothNames(String code) => languageNames[code] == _englishNames[code] ? _englishNames[code]! : '${languageNames[code]} (${_englishNames[code]})';

/// Sections of the reference that go beyond the web page, as
/// `(heading, Markdown body)`.
const _reference = [
  (
    'AI assistant',
    '''- Optional (Design → AI assistant, the command AI, the status-bar button, or the address `$siteUrl?ai=1`): an AI agent in a panel docked beside the drawing (a bottom sheet on phones) that works on the open project with a model of Anthropic, OpenAI, Google, xAI, Meta or OpenRouter, chosen in its settings, through the user's own API key. Requests go straight from the browser (or the desktop build) to that provider's API, with no server in between; each key is sent only to its own provider.
- Starting with the AI: the app opens on an empty project with a start screen that asks where the area to irrigate is (an address or place searched on OpenStreetMap, the user picking among the matches, or coordinates in any usual form; the project is georeferenced there and the satellite map shows) and whether to design with the assistant. "Design with AI" opens the assistant beside the drawing with the place and the user's description (or a request to start a new design) waiting in its box, nothing sent before Send; "Start without AI" leaves the user on the empty, georeferenced project. The screen can be turned off, and it is not shown when the address already says what to open (an example, the tutorial or a shared project) or after recovered work. Examples and the tutorial stay under Help → Welcome and example gallery and File → Examples.
- Models, with the user's own key of each company: Claude Fable 5.2, Claude Opus 5.5 (the default), Claude Sonnet 5.5 and Claude Haiku 5.5 from Anthropic; GPT-6 Astra, GPT-6.1 Sol, GPT-6.1 Terra and GPT-6 Luna from OpenAI, plus the earlier GPT-6 Sol and GPT-5.6 Terra; Gemini 4 Argon, Gemini 3.8 Flash and Gemini 3.5 Flash-Lite from Google (the two Flash models have a free tier, on which Google may use the content to improve its products); Grok 4.7 and Grok 4.3 from xAI; Muse Wonder, Muse Spark 1.3 and Muse Ember from Meta; and through OpenRouter, with one key, those companies' models, two routers (one of them over free models) and any other model of OpenRouter's list, added with "More models…" (a model that calls no tools only talks; one that reads no pictures gets none). Up to five depths of reasoning, as each model takes them. The panel shows the tokens of every answer and a cost estimate at list prices. The clients of Google, xAI, Meta and OpenRouter were written from those companies' documentation of November 2026 and tested against scripted transcripts, not against the live services.
- Second opinion: a button on the last answer, or `/second`, has another model (of another company when the user has its key) check the answer against the project data in one request without tools; the review is shown apart, counted in the cost, and reaches the first model only if the user sends it on.
- What it does: it answers questions about the open project and works with the program's own tools (75 tools, 216 more operations, every menu command and about 150 settings): it lists and reads items, reports, design messages and elevations; creates, changes, moves and deletes items; sets the parameters, the catalogue, the system flows and the quote; runs the design, the analyses, the design assistant's fixes and the optimisation; lays out sprinklers, generates lateral blocks, divides fields, fits pivots, maps vegetation, chooses pumps, places air valves, routes wires, writes the technical report and exports files. It keeps a to-do list, asks the user when something is missing, presents its plan, keeps AI notes in the project and reads the design playbooks and the manual when it needs them.
- Vision: it takes pictures of the drawing over the satellite image (the default whenever the project is georeferenced) or the map, with an exact pixel-to-world mapping, as large as the model reads them pixel for pixel (up to 2576 pixels and about 3.6 megapixels on Claude Fable 5.2, Opus 5.5, Sonnet 5.5 and Haiku 5.5); it colours the drawing in its pictures by zone, pressure, velocity or pipe size, marks the design messages at their items and its own changes (added, changed, removed), zooms into parts, snaps positions read on a picture onto existing items, previews proposed geometry before drawing it, and reads the terrain as hillshade, contours, slope, aspect and profiles. After each round of changes it gets a picture framed on what changed (a setting, on by default). It outlines a field, lawn, pond or roof from one point inside it by image analysis on the imagery (`trace_region`), or every field of an area at once (`trace_fields`), and before exporting a drawing sheet it looks at the sheet as it will print, with a check of overlapping, tiny or cut texts, the viewport fill, the title block, the north arrow, the scale bar and the legend (`preview_sheet`). It finds a site from an address (OpenStreetMap Nominatim), sets the georeference and the base map, downloads the terrain and the climate, imports the drawings and GIS files the user attaches (also pasted or dropped on the panel) and adds catalogue items from an attached data sheet (PDF, image or text), checked before they go in.
- Pointing, voice and field photos: "Mark a point" and "Mark a line" above the message box put orange marks labelled A, B, C… on the drawing, with optional notes, which go with the next message with their coordinates and show in the assistant's pictures (they are not saved with the project); a microphone button dictates the message through the browser's speech recognition (Chrome, Edge and Safari); a photo with GPS tags comes with where it was taken in the project and the nearest item, and the assistant can pin it there as a review comment keeping a small copy of the photo and what it read in it (`add_photo_comment`).
- Review: `/review`, or the tile at the start of a conversation, runs a read-only review whatever the mode: the assistant looks at the zones, the messages and the pressures over the drawing, reads the messages and the report tables and answers with a checklist (OK, attention or problem, with the figures and where to fix each point), changing nothing.
- Control: read only; plan first; ask before each change (the default, with Apply and Skip); or apply changes automatically (saving files, the georeference and large deletions are always confirmed). The user can type while it works and stop it at any time; the changes of each answer can be undone in one click, and every message has "Rewind to here". After an error or a stop the answer offers Try again (the same message, when nothing of it reached the model) or Continue; approving a plan to run automatically applies to that task only. A task ends at its step limit (50 by default) or at its spending cap (2 US dollars by default, with Continue). Long conversations are summarised on the provider's side (Anthropic and OpenAI).
- What is sent, and when: nothing before the user presses Send; then the message, any attached files, the project data the user ticks, the earlier messages of the conversation and the program's instructions; while answering, the results of the tools it uses, pictures included. Voice dictation sends the sound of the voice to the browser's speech service (Chrome uses Google's servers, Edge Microsoft's and Safari Apple's), which returns the text; the app neither records nor keeps the audio. Conversations are kept in the browser's storage by project (the 12 most recent, never the keys; a setting turns this off and deletes them), so a reload brings them back, but they are not saved with the project, so shared files and links never carry them; a pinned field photo is kept in the project file and left out of share links.
- The provider bills the use to the user's account. The key stays in memory for the session unless the user chooses to remember it on the device; it never goes into project files, autosave, share links or exports.''',
  ),
  (
    'Design workflow',
    '''1. **Project details and parameters**: name, client, site, designer and notes (printed in the sheet title block and the reports), metric or US units, and the design parameters: friction formula, water temperature, mains frequency (50 or 60 Hz), pressure windows, velocities and economics.
2. **Background**: import a DXF, DWG, DGN or PDF plan, KML/KMZ, shapefile, GeoJSON, GPX, survey CSV, GeoTIFF or aerial image, draw boundaries, buildings and roads, or walk them with the device GPS. Images and plans out of scale are fitted by aligning two points. The drawing stays fluid with tens of thousands of items and hundreds of layers: it is kept as a picture between frames, and a heavy drawing follows pans and zooms as a moved picture, sharp again once the view rests. A georeference (UTM zone and origin; datum shifts for SIRGAS 2000, SAD 69 and Córrego Alegre) enables base maps, online elevation and climate and the georeferenced exports.
3. **Terrain**: contour lines, spot heights and breaklines drawn or imported, LAS point clouds, LandXML surfaces, an elevation GeoTIFF, or elevation downloaded for the area; contours, slope and aspect maps generated from the model and a 3D view.
4. **Hydraulic layout**: by hand, with the lateral-block and sprinkler-grid generators, or with the automatic design tools: water supply, pumps, mainline, zone valves and, downstream of each valve, submains, laterals, drip tapes, single emitters and devices (filters, pressure-reducing, pressure-sustaining and flow-control valves, meters, backflow preventers, air and check valves); valve-in-head sprinklers on the mainline; centre pivots, linear moves, travellers and surface irrigation. Irrigated areas carry the crop, the soil, the efficiency and the water balance.
5. **Management**: system flows, i.e. which valves, valve-in-head stations and pivots open together, with start time and duration; grouped automatically within the supply flow, for the least pumping energy or around a time-of-use tariff.
6. **Check**: unconnected items, pipes crossing without a junction, dead ends, zones without emitters or mixing emitter families, missing catalogue items, missing terrain.
7. **Design (F5)**: zones, mainline, telescoping, flushing, water hammer, valve wiring and materials; or only zones, only the mainline, or an analysis of the current diameters (also automatically while editing). Further studies on demand: hydraulic transients, the 24-hour simulation, air valves, fertigation, on-demand operation, pipe criticality, roughness calibration, pump selection and design alternatives compared side by side.
8. **Reports and plotting**: reports panel, PDF sheet sets with title block, legend, north arrow, scale bar, bill of materials, construction details, charts and revision table, a commercial quote, and exports to other CAD, GIS, survey and BIM programs, to EPANET and to spreadsheets.''',
  ),
  (
    'Hydraulic engine',
    '''- Friction: Hazen-Williams (default), Darcy-Weisbach (Swamee-Jain, Colebrook, laminar and transition), Scobey (sprinkler laterals of steel and aluminium) or Manning, with the water viscosity from its temperature (20 °C by default).
- Minor losses as a share of the length (5 % by default) or from the fittings actually used (bends, tees, reducers) with their coefficients; valves and devices by `h = K·Q^n + C`.
- Emitters by `q = k·H^x`, wetted radius by `R = a·H^b`; pressure-compensating and turbulent drippers, micro-sprinklers, sprinklers, bubblers, guns and demand points.
- Network solver: the Global Gradient Algorithm (Todini and Pilati), the method of EPANET, with pressure-dependent emitters, fixed and variable-speed pumps (a variable-speed pump holds a target outlet pressure), pressure-reducing, pressure-sustaining and flow-control valves (hydrant flow limiters) and check valves, on a sparse LDLᵀ factorisation; parts of the network cut off by closed links are levelled instead of being solved with near-singular conductances.
- Pumps: Q-H curves with efficiency and NPSH required (NPSH and suction-lift checks), submersible pumps at the water level; a fixed-speed pump on mains of another frequency than its curve turns in proportion (a 60 Hz curve on 50 Hz mains: 5/6 of the speed, 69 % of the head).
- Laterals and tapes are lumped into at most 100 nodes each (adjustable), so lines with hundreds of emitters stay fast.
- Terrain elevation at every node; emitter pressure accounts for ground level, riser height and burial depth.
- Uniformity: Christiansen CU, low-quarter DU, Keller-Karmeli emission uniformity EU (with the manufacturing CV and emitters per plant), statistical uniformity and flow variation; overlap CU for sprinklers with a wetted radius; a densogram adds up the water every sprinkler applies as drawn (arc, orientation and design pressure) and gives the rate map with CU, DU and the scheduling coefficient per irrigated area.
- Water hammer in the design step: wave celerity from pipe material and wall, Joukowsky surge, critical time 2L/a and comparison with the pipe pressure class, including the valve closure time. The full transient analysis is described below.
- Flushing of drip tapes with open ends at the flushing velocity (0.3 m/s and 1 m end pressure by default).
- The calculation runs in a Web Worker, off the interface thread.''',
  ),
  (
    'Transients and extended-period simulation',
    '''- Hydraulic transients by the method of characteristics (Wylie and Streeter; Chaudhry) on the mainline of every system flow: the zone valves closing in the closure time of the parameters, a power failure tripping the pumps (pump and motor inertia estimated by Thorley and Faithfull from the rated power and speed, or given) and an isolation valve closing.
- Every pipe takes its wave celerity from its wall and material (Korteweg) and its pressure class at the water temperature; vapour cavities by the discrete vapour cavity model; the air valves drawn on the mainline act as combination air valves; surge vessels; the barometric head follows the site elevation.
- Results: head and pressure envelopes per pipe against the class and against vacuum, the profile along the critical path, the pressure in time at the pump and at the worst point, and findings explained by the design assistant.
- Air valves placed and sized along the mainline profile after AWWA Manual M51: high points, changes of slope, long runs, pump discharges and the points where the grade line or the transient minimum comes close to the pipe.
- A 24-hour extended-period simulation with time steps as in EPANET: tanks, the system flows at their start hours, pumps on while their flows run, pressures in time, and the energy and its cost at a time-of-use tariff.''',
  ),
  (
    'Pipe sizing and optimisation',
    '''- **Linear programming** (default): every pipe may be built from fractions of the candidate diameters; the programme minimises the annualised pipe cost plus the energy cost of the inlet pressure, subject to the pressure window of the critical emitters (end, highest and lowest point of every lateral), and repeats with the emitters found at the limits (up to four rounds).
- **Maximum velocity** method as the classic alternative (defaults 2.0 m/s in laterals, 1.5 m/s in submains, 2.0 m/s in the mainline).
- Greedy repair along the critical path, non-increasing diameters downstream and **telescoping** (up to 3 diameters per submain or mainline pipe by default).
- **Pressure class**: the linear programme and the greedy method only offer pipes whose class, derated for the water temperature (PVC and PE), holds the operating pressure found; the sizing repeats (up to three passes) until it does. The water hammer estimate and the transient envelopes are compared with the class too.
- **Looped mainlines**: the linear programme is repeated with the redistributed flows until they settle; the final analysis checks the result.
- The mainline is sized over all system flows with the energy weighted by the operating hours of each, with pump operating points and supply duties (flow, available and required pressure, deficit, annual energy).
- Economics: interest rate, term, energy tariff (also by time of use), pump efficiency and operating hours; costs in the currency of the user's region.
- **Pump selection**: the catalogue pumps ranked for the duty of each water supply, suitable ones first, then by life-cycle cost.
- **Design assistant**: every problem explained (what happened, why it matters, how to fix it), impossible settings detected, one-click corrections, *Fix automatically* and *Optimise design* (lowest annual cost that meets every requirement, kept only when it improves).''',
  ),
  (
    'Automatic design',
    '''- **Sprinkler layout** for lawns and beds: heads in the corners, along every edge and on a grid inside (convex or concave areas, buildings and beds left out), every arc opening into the area, matched-precipitation nozzles and a preview of CU, DU and the scheduling coefficient.
- **Zoning by flow**: heads or drip areas grouped into compact valve zones within the valve and supply limits, never mixing emitters that apply water at different rates.
- **Routing**: a valve for every zone and zone pipes joining its heads as a tree, around buildings and the other zones, then a mainline tree from the water supply or pump to every valve.
- **Field subdivision**: an agricultural field cut into blocks of equal net area, by area or by flow, as strips or a grid, with service roads; every block is ready for the lateral-block generator.
- **Orchard drip rings** around every tree, and **sports and golf templates** (football pitch, running-track infield, green, tee and fairway).
- **Pivot fit**: the largest full-circle pivot, or the part-circle pivot that irrigates the most, that fits a field and its obstacles, from standard span lengths.
- **Vegetation detection** in aerial imagery (the satellite base map in view or an aerial photo in the drawing), on the device with no online service: lawns and trees or shrubs found by an excess-green index with an automatic threshold, outlined and simplified into irrigated areas with agronomic presets, plus exclusion outlines.
- **Crop rows from the image**: the direction, the spacing and the number of planting rows of a field read from the satellite base map or an aerial photo, with a confidence figure and, where the image shows them, the plant spacing and the canopy ground cover; on the device, with no online service and no AI key. Applied to the area, they become the defaults of the field blocks, the orchard rings and the lateral blocks.''',
  ),
  (
    'Agronomy, operation and energy',
    '''- Site climate: monthly normals downloaded for the site (Open-Meteo historical weather from the ERA5 reanalysis, or NASA POWER) or typed in; reference evapotranspiration by FAO Penman-Monteith (Hargreaves-Samani as the alternative).
- Crops: FAO-56 single crop coefficient curves by stage (initial, development, mid-season, late), reduced for localized irrigation; soils of the 12 USDA texture classes.
- Effective rain (USDA-SCS TR-21, its simplified form, FAO dependable rain, the FAO empirical formula or a fixed percentage) and the leaching requirement for salinity.
- Requirement tables per irrigated area, crop cycle and month or stage: ETo, Kc, ETc, effective rain, net and gross depths, readily available water, interval, hours per event and volumes.
- Soil water balance, irrigation interval and run times; controller programme per system flow (days and start times), exportable as CSV.
- Climate risk over the years: the design checked against the daily series of the site since 1984 (NASA POWER, or the site's own daily series): ETo by FAO-56 Penman-Monteith, the daily soil water balance of every area season by season, without a limit and limited to what the designed system can apply a day; yearly requirement and peak-period demand at P50, P80, P90 and P95 beside the design figure, the reliability of the system, the worst years, the dry spells and a Sen / Mann-Kendall trend.
- Irrigation forecast: the weather forecast of the site (MET Norway Locationforecast, or Open-Meteo for non-commercial use) turned into daily ETo and a soil water balance run forward from today: irrigate or skip, net and gross depth, run time and the water budget % for the controller, per irrigated area. Nothing is fetched until the user asks, and the project is not changed.
- The programme played on the plan: a player over the drawing shows, at every moment of the programme's cycle, the zones that run, the pipes by velocity and flow, the pumps on and off and the reservoir level; it exports the moment as a PNG, the cycle as an animated GIF and the programme as a calendar file (`.ics`).
- Landscape water budget (MAWA and ETWU after the California Model Water Efficient Landscape Ordinance) with cycle-and-soak scheduling; wetted bulb of drip emitters and the wetted percentage.
- Fertigation: travel times from the injection point to every outlet, the injection plan that delivers the dose and flushes it out before the irrigation ends, and the check of a venturi injector.
- Energy and operation: zones grouped into system flows for the least pumping energy; flows scheduled around a time-of-use tariff and an irrigation discount window (such as the Brazilian rural irrigation discount); on-demand networks of hydrants (Clément flows and a random-demand check, after FAO Irrigation and Drainage Paper 59); pipe criticality (N−1); roughness calibration from field readings; solar (photovoltaic) pumping sized and compared with grid energy.''',
  ),
  (
    'Valve wiring',
    '''- Controllers (stations, output voltage, cost, sensors) and wire routes, drawn by hand or routed automatically along the pipe trenches; every valve gets a station number by distance; a master valve opens with every zone and a pump start relay with the pump.
- Conventional wiring: station and common wire sizes chosen at the lowest cost that keeps every solenoid above its minimum voltage (20 V by default) while it opens with the other valves of its system flow already on (inrush and holding currents, route lengths plus slack).
- Two-wire (decoder) systems: one pair along the routes with decoders of 1, 2, 4 or 6 stations at the valves, sized for the idle and running currents.
- Valve-in-head stations are wired like valves (their solenoids in parallel, or a decoder at the heads).
- Electrical report (route, wire lengths, sizes, solenoid voltage) and wires, controllers, decoders and connectors in the bill of materials; stations and simultaneous valves checked.''',
  ),
  (
    'Terrain',
    '''- Sources: drawn contour lines, spot heights and breaklines, survey points (CSV, TXT, XYZ, PNEZD, decimal comma accepted), DXF, DWG and DGN polylines with elevation, KML with altitude, shapefiles with Z or an elevation attribute, GPX waypoints, LandXML surfaces, LAS point clouds (ground class by default, decimated on a grid), elevation GeoTIFF and online elevation.
- Online elevation for the project area or a pasted coordinate (decimal, map link or degrees/minutes/seconds), from free keyless services: Terrain Tiles on AWS Open Data (SRTM and other models, the default) and Open-Meteo (Copernicus DEM); OpenTopoData in the desktop builds.
- Digital terrain model by Delaunay triangulation (TIN) with breaklines as constrained edges, or inverse-distance interpolation; contours generated from the model; slope and aspect maps with the share of the area in each slope class; 3D view with the pipes draped on the ground; longitudinal profiles with the pipe and the hydraulic grade line.''',
  ),
  (
    'Centre pivots and mechanised irrigation',
    '''- Centre pivots and linear moves with radius, spans and towers, applied depth, cycle time, end pressure, sector angle and end gun, fed from the mainline as a demand; report of towers, spans and sprinklers, and a check of the application rate against the soil intake limit.
- Sprinkler package (nozzle chart): outlets span by span, the flow of every outlet for a uniform depth, pressure regulators, drops, numbered nozzles, end gun and booster pump, checked against the pressure along the machine; the timer chart (depth against the percent timer) from the drive train.
- Corner arm with its guide path (warning where the tip would jump), variable-rate prescriptions by zones or sectors (CSV), and the electrical design of the machine (span cable voltage drop, generator).
- Hose-reel travellers (lane spacing by wind, travel speed, hose friction, inlet pressure and power), surface irrigation (furrows, borders and level basins by the volume-balance model of FAO Irrigation and Drainage Paper 45) and gated pipe (gate openings or hole sizes for the furrow flow).''',
  ),
  (
    'Component catalogue',
    '''- Seven groups: pipes, emitters with nozzles, tapes and driplines, valves and devices, pumps (Q-H curve, efficiency and NPSH curves, the frequency the curve was measured at), fittings and wires.
- Default catalogue: 17 pipes (PE 16–50 mm, PVC DN 35–250, HDPE 110 and 160, 6" steel), 9 emitter families and a demand point, 6 tapes and driplines, 36 valves and devices from 1" to 6" (solenoid, hydraulic and master valves, pressure-reducing and pressure-sustaining valves, hydrants with flow limiters, gate and check valves, filters, meters, backflow preventers, air release valves), 18 pumps (centrifugal 1 to 100 hp, submersible 3 to 30 hp), about 330 fittings and 12 copper wires (1 to 10 mm² and AWG 18 to 8), with illustrative prices.
- 14 manufacturer packs (259 items) built from published data sheets: Hunter, Rain Bird, Toro, Netafim, Rivulis, NaanDanJain, Jain, Nelson and Senninger (sprinklers, micro-sprinklers, drippers, tapes and driplines, pivot sprinklers, big guns, valves and regulators), Irritec (driplines and drippers), Bermad (hydraulic valves), Schneider (centrifugal and submersible pumps, curves at 60 Hz), and Amanco Wavin and Multilit (PVC irrigation pipes). Nozzle curves are fitted to the manufacturers' tables; prices are left to the user.
- The catalogue editor imports and exports JSON, CSV and Excel; packs in the `.oci.cat` JSON format load from a file or a URL, so dealers can publish their own.
- Curves digitised from a picture: a pump curve (head, efficiency, NPSH and shaft power), an emitter flow–pressure curve or a sprinkler radial profile read from a picture of a data sheet (two calibration points per axis, linear or logarithmic, automatic tracing by colour, the fit and its residuals) and put into the project catalogue.''',
  ),
  (
    'Reports and plotting',
    '''- Reports: zone summary, pipes, emitters, mainline and supply duties, devices, bill of materials with automatically selected fittings (couplers, elbows, tees, crosses, reducers, end caps, take-offs, risers) for the whole design, per sector or for the current selection, water requirements, agronomy, controller schedule, flushing, water hammer, pivots and spans, pivot sprinkler packages, valve-in-head stations, valve wiring, hydraulic grade line chart, terrain profile, densogram and messages; conditional labels show results on the drawing.
- Commercial quote from the bill of materials: margin, labour, trenches, extra lines, discount, taxes, freight, validity, payback (NPV and IRR) and a construction schedule; for Brazil, BNDES FINAME codes and the CONAMA 284 licensing category (informative).
- PDF sheets from A4 to A0, Letter and Tabloid, automatic or fixed scale, title block, legend, north arrow, scale bar, images and the base map, bill of materials on the sheet and attached report pages; sheet sets (an overview plus one sheet per zone or irrigated area, the others greyed or hidden, and extra windows at their own scale); construction detail sheets drawn with the design's values (trench, thrust block, valve box, sprinkler riser or swing joint, drip line start, air valve, filter station, pump suction); charts (mainline grade line per system flow, profile, pump curves with duty points); a revision table from the revision clouds. Text in every script of the 20 languages (embedded Noto fonts, Arabic and Indic shaping, right-to-left text).
- PNG image of the sheet (96 to 300 dpi); every table to PDF, Excel (one sheet per table, numbers as numbers), CSV and TXT.
- Design scorecard: the designed project graded from 0 to 100 and from A to E in seven categories (uniformity, hydraulics, energy, water and soil, economy, robustness, completeness); every indicator with its value, its target and where the target comes from, a score by a stated piecewise-linear function, the points it could add and its weakest point; indicators without data are left out of the averages. A radar of the categories, what to improve first, the comparison with a remembered score or an alternative, and export to CSV, Excel and PDF.''',
  ),
  (
    'File formats',
    '''| Format | Import | Export |
|---|---|---|
| `.oci.json` project | yes | yes |
| DXF | R12 to 2018: lines, polylines with bulges, circles, arcs, ellipses, splines (NURBS), hatches, solids, texts, points, layers, blocks and dimensions | R2000 (AC1015) with native entities (polylines with arcs, splines, hatches, dimensions, leaders, multiline text; symbols and hydraulic items as blocks with attributes; layers with true colours and dashed linetypes), or R12 by layer for older programs |
| DWG | R13/R14 (partial), 2000, 2004, 2007, 2010, 2013 and 2018: the same entities, layers, blocks and dimensions | 2000 (AC1015): the same native drawing, with colour indices |
| DGN | V7: elements, cells, levels as layers, 2D and 3D | — |
| PDF | plans as an underlay: vectors, texts, images and PDF layers, scale 1:N read from the sheet | sheets, sheet sets, detail sheets and reports |
| KML / KMZ | placemarks, folders as layers, GPS tracks, altitude as elevation | folders per layer, WGS84 |
| Shapefile (zip with DBF, PRJ, CPG; several per zip) | points, lines, polygons, Z variants, attributes in UTF-8 or Latin-1, datum of the .prj | one shapefile per layer and geometry with typed attributes (diameters, flows, pressures), zipped |
| GeoJSON | every geometry type, the `crs` member honoured | FeatureCollection with attributes |
| GPX | waypoints as spot heights, tracks and routes as lines | items as waypoints, pipes and outlines as tracks, for staking out |
| LandXML 1.2 | terrain surfaces (TIN) and survey points | terrain surface, point items for stake-out and pipe networks |
| LAS 1.0–1.4 | point clouds as terrain | — |
| EPANET .inp | the network as drawing items | one network per system flow |
| IFC 4 | — | the site, its terrain and the irrigation system for BIM, georeferenced |
| CSV, TXT | survey points | report tables, controller programme |
| XYZ, PNEZD | survey points | — |
| GeoTIFF | elevation grid or background image | — |
| JPG, PNG, world file | background image, georeferenced or aligned by 2 points | PNG of the sheet (96 to 300 dpi) |
| SVG | — | sheet in millimetres, one group per layer |
| XLSX | catalogue prices | reports and catalogue |''',
  ),
  (
    'Storage, privacy and network access',
    '''- Autosave in the browser (made in the background: the browser compresses the copy beside the app, so a large project does not hold the window after a design), recent projects, the last 10 versions of every project and recovery on start-up; a project too large for the browser copy (about 3.5 MB compressed) is announced once, and embedded images are the first thing left out of that copy.
- Save and Open work with `.oci.json` files on the user's disk; OpenCADIrrigation runs no server and has no accounts.
- Share by link: the whole project, compressed, travels in the fragment of the address (`#p=…`), which browsers never send to a server; embedded images, the photos of comments and results stay out of the link, and the receiver designs again.
- Offline start: after the first visit, the app's own service worker keeps a copy of the app (about 20 MB, once per version), so the installed app and the site start without a network; the language packs and the PDF fonts are kept once used. A new version downloads in the background: the app offers to reload into it (unsaved work goes to the autosave), or it is used from the next start.
- Network use: the app and all its fonts (those of every script and symbol included) come from the site itself; base maps (OpenStreetMap, OpenTopoMap, CARTO, Esri, Google Maps with the user's own key, or custom XYZ and WMS addresses), online elevation and climate, the weather forecast, address search, catalogues loaded by URL and, if used, the AI assistant (only the company the user chose; OpenRouter passes the request on to the company that runs the model) are reached when the user uses them. Keys typed by the user go only to their own service.
- Visit statistics: every page of the site and the app load Google Analytics 4 with its cookies (each page viewed, and an `app_start` event at each start of the app; advertising always denied; the address goes without the `#` fragment, where share links carry the project); no notice asks, and Decline in Cookie settings at the foot of the pages deletes the cookies and stops loading the statistics in that browser.
- Privacy policy: ${siteUrl}privacy/ (controller: the maintainer of OpenCADIrrigation, reached through the project's issues); terms of use: ${siteUrl}terms/ (MIT licence, no warranty, a design aid whose results a qualified professional checks and signs).''',
  ),
  (
    'Phone, tablet and field work',
    '''- A compact layout for phones and tablets.
- Device GPS (the browser's geolocation): record a walk and finish it as an irrigated area, a closed outline or a line; mark a point at the current position; the distance and bearing to the selected item for staking out.
- GPX export of every designed item for a GPS receiver, and LandXML points for survey instruments.
- After the first visit the app starts without a network in the field; maps, online elevation and climate and the AI assistant need one.''',
  ),
  (
    'Command line and engine API',
    '''- `dart run bin/oci.dart --help`: the commands design, analyze, check, export and bom work on `.oci.json` projects in the Dart VM, without Flutter or a browser, with the same engine as the app.
- `package:opencadirrigation/core/api.dart` exports the whole public surface of the engine (`lib/core`, plain Dart): projects, the design, reports, exporters, the hydraulic solver, transients, the extended-period simulation, air valves, the layout automation, agronomy, mechanised machines and the file formats.
- Documented in [docs/API.md]($appRepositoryUrl/blob/main/docs/API.md) (Portuguese: [docs/API.pt-BR.md]($appRepositoryUrl/blob/main/docs/API.pt-BR.md)); every snippet there is run by the tests.
- MCP server: `dart run bin/oci.dart mcp --root <folder> [--read-only]` serves the engine over the Model Context Protocol (stdio) to any AI application that speaks it: 21 tools over the command line's functions (create, import, read, edit, design, analyse, check, bill of materials, report tables, exports), confined to the folder given, with nothing sent to the internet ([docs/MCP.md]($appRepositoryUrl/blob/main/docs/MCP.md)).''',
  ),
  (
    'Known limitations',
    '''- The transient analysis and the 24-hour simulation work on the mainline of each system flow, with every zone seen as an orifice or a demand at its valve; laterals and drip tapes are not part of the transient model. The water hammer figure of the design step is a Joukowsky estimate.
- Looped mainlines are sized by repeating the linear programme with the redistributed flows; the final analysis checks the result.
- Pressure-compensating emitters in grossly undersized networks (flows many times what the pipes can carry) may still keep the solver from converging; the design then reports `not_converged` instead of figures.
- The terrain triangulation takes at most 12 000 samples: a larger terrain uses a uniform subset (announced once), while inverse-distance interpolation uses every sample.
- Refused on import: DGN V8, LAZ (compressed LAS), BigTIFF, rasters above 100 million pixels and encrypted PDFs; JPEG 2000 and JBIG2 images inside PDFs are skipped, and scanned plans come in as images, not lines. DWG R13/R14 is read only in part.
- The DWG export uses colour indices; the DXF 2000 export also carries true colours.
- The densogram uses one spray profile for every head of the map.
- Vegetation detection and the assistant's field outlines are plain image processing: they need clear colour imagery, their outlines should be checked, and the imagery's terms of use apply.
- Voice dictation needs a browser with speech recognition (Chrome, Edge or Safari; not Firefox nor the desktop build).
- The AI assistant needs the user's own API key and a network; a model can be wrong, so its answers and changes should be checked (every change can be undone).
- The automatic copy in the browser keeps projects up to about 3.5 MB compressed; larger projects should be saved as files.
- No simultaneous editing; projects are shared as `.oci.json` files or by link.
- Native Android and iOS builds are not built or tested; the web app works on phones and tablets.
- Projects with hundreds of tapes per zone take a few seconds per zone; flushing is the heaviest step.''',
  ),
];

/// Deep links, as `(query, effect)`.
const _deepLinks = [
  ('?example=<id>', 'opens a ready example (ids in the table above)'),
  ('?tutorial=1', 'opens the interactive tutorial (any step number works)'),
  ('?design=1', 'designs the project on load'),
  ('?ai=1', 'opens the AI assistant beside the drawing'),
  ('?lang=<code>', 'interface language for this visit (codes in the language list)'),
  ('#p=<data>', 'a project shared by link (File → Share by link): it travels compressed inside the address and opens in a new tab; nothing is uploaded'),
];

String _examplesTable(String Function(SiteExample) url) {
  final en = siteText('en');
  return ['| Id | Example | What it shows |', '|---|---|---|', for (final ex in en.examples) '| `${ex.id}` | [${ex.title}](${url(ex)}) | ${ex.text} |'].join('\n');
}

/// llms.txt: the summary a language model reads first.
String renderLlmsTxt() {
  final en = siteText('en');
  final b = StringBuffer()
    ..writeln('# OpenCADIrrigation')
    ..writeln()
    ..writeln('> ${en.faq.first.$2}')
    ..writeln()
    ..writeln(en.intro)
    ..writeln();
  for (final (label, value) in _facts()) {
    b.writeln('- $label: $value');
  }
  b
    ..writeln()
    ..writeln('## Application')
    ..writeln()
    ..writeln('- [OpenCADIrrigation]($siteUrl): the app and its page in English; the app opens in the visitor\'s language when it speaks it')
    ..writeln('- [${en.tutorial}]($siteUrl?tutorial=1): a guided tour of every function on a sample project')
    ..writeln('- [Sized example]($siteUrl?design=1): the sample orchard, designed as soon as it opens')
    ..writeln('- [AI assistant]($siteUrl?ai=1): the app with the AI assistant open beside the drawing')
    ..writeln('- [Source code]($appRepositoryUrl): the whole application in Dart and Flutter, MIT licence')
    ..writeln('- [Engine API]($appRepositoryUrl/blob/main/docs/API.md): the calculation engine as a Dart library, and the command line `bin/oci.dart`')
    ..writeln()
    ..writeln('## AI assistant')
    ..writeln()
    ..writeln(
      '- Optional: models of Anthropic (Claude), OpenAI (GPT), Google (Gemini), xAI (Grok), Meta (Muse) or, through OpenRouter, hundreds of others, with the user\'s own API key, called straight from the browser with no server in between; that company bills the account, and nothing is sent before the user presses Send',
    )
    ..writeln(
      '- It draws and designs with the program\'s own tools: finds the site, looks at the satellite image and the terrain, lays out sprinklers and drip, divides fields, routes pipes and valves, runs the sizing, fixes warnings, optimises and writes the report; every change waits for approval (or applies automatically) and can be undone',
    )
    ..writeln('- [Open the AI assistant]($siteUrl?ai=1) (Design → AI assistant in the app); details under "AI assistant" in the complete reference')
    ..writeln()
    ..writeln('## Reference')
    ..writeln()
    ..writeln(
      '- [Complete reference](${siteUrl}llms-full.txt): features, design workflow, hydraulic methods, transients, sizing, automatic design, agronomy, catalogues, file formats, the AI assistant, offline and field use, examples, deep links, limitations and FAQ in one Markdown file',
    )
    ..writeln('- [User guide](${manualUrl('en')}): the manual of the app, chapter by chapter, as web pages (in Portuguese at ${manualUrl('pt')})')
    ..writeln()
    ..writeln('## ${en.examplesTitle}')
    ..writeln()
    ..writeln(en.examplesIntro)
    ..writeln();
  for (final ex in en.examples) {
    b.writeln('- [${ex.title}]($siteUrl?example=${ex.id}): ${ex.text}');
  }
  b
    ..writeln()
    ..writeln('## Other languages')
    ..writeln()
    ..writeln('The same page, written in each language of the app:')
    ..writeln();
  for (final l in siteLanguages.where((l) => !l.isRoot)) {
    b.writeln('- [${_bothNames(l.code)}](${l.url}): ${siteText(l.code).title}');
  }
  b
    ..writeln()
    ..writeln('## Optional')
    ..writeln()
    ..writeln('- [Sitemap](${siteUrl}sitemap.xml): every language page with its hreflang alternates')
    ..writeln('- [Privacy policy](${siteUrl}privacy/): what the app keeps in the browser, what it sends and to whom, the visit statistics and their consent')
    ..writeln('- [Terms of use](${siteUrl}terms/): the MIT licence, no warranty, and the professional who checks and signs a design made with the app');
  return b.toString();
}

/// llms-full.txt: everything a language model may need, in one file.
String renderLlmsFullTxt() {
  final en = siteText('en');
  final b = StringBuffer()
    ..writeln('# OpenCADIrrigation: complete reference')
    ..writeln()
    ..writeln('> ${en.faq.first.$2}')
    ..writeln()
    ..writeln(
      'This file describes OpenCADIrrigation for language models and other automated readers. The application itself is at $siteUrl; a summary is at ${siteUrl}llms.txt. Version $appVersion, updated $siteLastMod.',
    )
    ..writeln()
    ..writeln('## At a glance')
    ..writeln()
    ..writeln('| | |')
    ..writeln('|---|---|')
    ..writeln('| Name | OpenCADIrrigation (one word, "CAD" in capitals) |');
  for (final (label, value) in _facts()) {
    b.writeln('| $label | $value |');
  }
  b
    ..writeln()
    ..writeln('## Who it is for')
    ..writeln()
    ..writeln(en.faq.firstWhere((f) => f.$1 == 'Who is it for?').$2)
    ..writeln()
    ..writeln('## ${en.featuresTitle}')
    ..writeln();
  for (final (name, text) in en.features) {
    b
      ..writeln('### $name')
      ..writeln()
      ..writeln(text)
      ..writeln();
  }
  b
    ..writeln('## ${en.howTitle}')
    ..writeln();
  for (final (i, (name, text)) in en.how.indexed) {
    b.writeln('${i + 1}. **$name.** $text');
  }
  b.writeln();
  for (final (heading, body) in _reference) {
    b
      ..writeln('## $heading')
      ..writeln()
      ..writeln(body)
      ..writeln();
  }
  b
    ..writeln('## ${en.examplesTitle}')
    ..writeln()
    ..writeln(en.examplesIntro)
    ..writeln()
    ..writeln(_examplesTable((ex) => '$siteUrl?example=${ex.id}'))
    ..writeln()
    ..writeln('## Deep links')
    ..writeln()
    ..writeln('Every page of the site accepts these parameters, for example $siteUrl?example=garden or ${siteUrl}pt/?tutorial=1:')
    ..writeln();
  for (final (query, effect) in _deepLinks) {
    b.writeln('- `$query`: $effect');
  }
  b
    ..writeln()
    ..writeln('## ${en.faqTitle}')
    ..writeln();
  for (final (q, a) in en.faq) {
    b
      ..writeln('### $q')
      ..writeln()
      ..writeln(a)
      ..writeln();
  }
  b
    ..writeln('## Languages')
    ..writeln()
    ..writeln(
      'The interface, the reports, the tutorial and the example projects are available in ${siteLanguages.length} languages. The app opens in the first language of the browser that it speaks, else in English. Each language has its own page:',
    )
    ..writeln()
    ..writeln('| Language | Code | Page | Description on that page |')
    ..writeln('|---|---|---|---|');
  for (final l in siteLanguages) {
    b.writeln('| ${_bothNames(l.code)} | `${l.code}` | ${l.url} | ${siteText(l.code).description} |');
  }
  b
    ..writeln()
    ..writeln('## Citing')
    ..writeln()
    ..writeln('OpenCADIrrigation, version $appVersion. $siteUrl (source code: $appRepositoryUrl, MIT licence)');
  return b.toString();
}
