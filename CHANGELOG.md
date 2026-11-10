# Changelog

What changed in each version of OpenCADIrrigation, newest first. The app shows its version in Help → About and in
the status bar; `pubspec.yaml` holds it, and the release checklist in [CONTRIBUTING.md](CONTRIBUTING.md#releasing)
adds the section of each new version here (a test fails when the current version has none). Portuguese:
[CHANGELOG.pt-BR.md](CHANGELOG.pt-BR.md).

## 1.7.0 (2026-11-10)

The AI assistant on the models of six companies, with a second opinion from another model, and new tools: crop rows
read on the satellite image, the climate risk over forty real years, the irrigation forecast of the coming days, the
programme played on the plan, a scorecard of the design and curves digitised from a catalogue picture; the engine as
an MCP server; share links that open again.

### AI assistant

- **Models brought up to date** (each company's documentation of 2026-11-10): Claude Fable 5.2 (US$ 8 / 40 per million
  tokens) takes the place of Claude Fable 5.1, and a choice or a kept conversation of 5.1 goes on with 5.2; Claude
  Sonnet 5.5 reads the cache at US$ 0.10; GPT-6.1 Terra (US$ 1 / 5) joins GPT-6 Luna as a fast model, and every GPT-6
  model takes the *Maximum* effort; pictures of the drawing go at up to 2576 pixels to the Claude models that read them
  at high resolution, Claude Haiku 5.5 included.
- **Six companies**, each with your own key and straight from the browser: beside Anthropic and OpenAI, **Google**
  (Gemini 4 Argon, Gemini 3.8 Flash and Gemini 3.5 Flash-Lite through the Interactions API with nothing stored at
  Google; the two Flash models with a free tier, on which Google may use the content to improve its products; Gemini 4
  Argon and 3.8 Flash at half price until 1 December 2026 and 1 January 2027), **xAI** (Grok 4.7 and Grok 4.3 through
  its Responses API; twice the price from 200 000 prompt tokens; a PDF goes as its text, since an attached file would
  turn on xAI's paid search), **Meta** (Muse Wonder, Muse Spark 1.3 and Muse Ember through the Meta Model API; only the
  *Standard* models, on which Meta does not train; Muse Ember three times the price above 200 000 input tokens) and
  **OpenRouter** (the Claude, GPT, Gemini, Grok and Muse models, the Auto Router and the Free Models Router with one
  key, billed to its credits).
- **Settings**: a row of company chips (a key icon on those with a saved key), then the models of the chosen company
  with their tier, prices and what to know (introductory price and its end, free tier, long-prompt rule, no pictures,
  no tools, router). One key is enough; the last model of each company is remembered. Switching to another company's
  model, or between two models of a company other than Anthropic, starts a new conversation; Claude models take over
  each other's.
- **More models…** (OpenRouter): OpenRouter's whole list, downloaded when asked (no key needed; the last copy works
  offline), with search, *Free only*, *Reads pictures* and *Calls tools* filters and sorting by price or name; the model
  chosen joins your list, is chosen at once and comes back when the app starts again.
- **A model that calls no tools** only talks (no tools in its requests, and it is told so); **a model that reads no
  pictures** gets none (your pictures, the tools' pictures and the drawing after a change left out, and both you and the
  model told).
- **Second opinion** (a button on the last answer, `/second`): another model, of another company when you have its key,
  checks the answer against the project data in one request without tools and says what holds, what does not and what
  to check; the review is marked, counted in the cost and read by the first model only after *Answer the review*.
- **Costs**: list prices per million tokens of every model with cached input, long-prompt rules and introductory prices;
  a router's pick that the table does not price costs what OpenRouter says it charged; the dearest models through
  OpenRouter answer at most 32 000 or 64 000 tokens, since OpenRouter holds the price of the largest answer against the
  balance while a request runs; a free model works under the spending cap. Long attachments are read by the cheapest
  model of the conversation's company.
- **Errors**: each company's own statuses and codes are read (no credit, billing not set up, spending limits, quotas with
  the wait the company asks for, moderation and safety blocks named), and OpenRouter's own words follow the app's text.
- The four new clients were written from each company's documentation and tested against scripted transcripts of the
  documented formats, not against the live services: no key was used.

### New tools

- **Crop rows from the image** (Design → Automatic design): reads on the satellite image, or a placed aerial photo, the
  direction and spacing of the planting rows of an orchard, coffee, vineyard, citrus or olive grove, how many cross the
  field and how sure the reading is, with the plant spacing and the canopy ground cover where the image shows them, by
  image processing on the device (no AI key); previews the rows over the image and the drawing, and in one undo step
  sets the area's row direction and spacing (the defaults of Subdivide a field into blocks, Orchard drip rings and
  Lateral block over it), its ground cover and guide lines of the rows. Irrigated areas keep the row direction (`rdir`),
  turned and mirrored with them.
- **Climate risk over the years** (Design → Agronomy): the design run through every real year of the NASA POWER daily
  series of the site from 1984 (downloaded once, about 2 MB, and kept on the device) or of the site climate's own
  series: FAO-56 Penman-Monteith ETo and the daily soil water balance of every area, without a limit and with what the
  designed system can apply a day; the P50/P80/P90/P95 and maximum of the yearly requirement, of the peak demand and of
  the peak ETo beside the design figures and the capacity, the reliability, the worst years, the longest dry spells, the
  volume pumped and the trend (Sen's slope, Mann-Kendall); a chart per year, an exceedance curve and two report tables in
  every export. Only the summary is kept in the project (`climateRisk`).
- **Irrigation forecast** (Design → Agronomy): the weather forecast of the site (MET Norway, free for professional work;
  Open-Meteo, non-commercial) turned, for each irrigated area and each of the coming days, into irrigate or skip, the
  net and gross depth, the run time at the design's application rate and the water budget (%) for the controller; the
  daily soil water balance runs forward from the soil state you give; ETo by FAO-56 Penman-Monteith with the radiation
  from the temperature range (or the service's own ETo); the tables export to CSV, XLSX and PDF; the answer is kept on
  the device while it is valid and never fetched again before the service allows. The project is not changed.
- **Play the programme on the plan** (Design → Agronomy, or *Play* in the Irrigation programme dialog): a player over the
  drawing runs through the cycle of the programme with play, pause, speed and a time line; the zones that water are
  tinted, the pipes coloured by velocity and sized by flow, the pumps on or off, with the clock, the flow, the pressure
  at the pump outlet and the reservoir levels. The moment exports as a PNG, the cycle as an animated GIF for a phone
  message, and the programme as a calendar file (.ics) for the grower's phone.
- **Design scorecard** (Design menu): the designed project graded 0–100 and A–E in seven categories (uniformity,
  hydraulics, energy, water and soil, economy, robustness, completeness), with a radar, what to improve first sorted by
  the points each change would add and a button to the tool that does it, and every indicator with its value, target,
  the standard or design parameter the target comes from, score and weight; indicators without data are left out,
  never guessed; compare with a remembered score or a saved alternative, run the ageing test, export as CSV, XLSX or
  PDF; the table and the radar also go into the report exports and the chart pages of the sheets.
- **Digitise a curve from a picture** (Design menu): open, paste or drop a picture of a catalogue chart, click two
  points on each axis (linear or logarithmic, any unit of the app; rotated or sheared scans read right), click along the
  curve or let the automatic trace follow its colour, and put a pump's head curve (with its efficiency, NPSH required
  and shaft power), an outlet's flow–pressure curve (q = k·Hˣ) or a sprinkler's radial profile into the catalogue in one
  undo step, the fit drawn over the picture with its residuals.
- The AI assistant reaches every one of them: `detect_crop_rows`, `apply_crop_rows`, `climate_risk`,
  `irrigation_forecast`, `programme_picture`, `export_programme_animation`, `export_programme_calendar`,
  `design_scorecard`, `fit_curve_points`, `apply_curve_points` and `export_curve_points` (216 operations in all).

### Engine and command line

- **MCP server**: `dart run bin/oci.dart mcp --root <folder>` lets any AI application that speaks the Model Context
  Protocol design irrigation systems with the engine on your own computer: 21 tools to make a project of a drawing or an
  example, read and edit its items and settings, design it, read every message of the design assistant with its
  explanation, the bill of materials and any report table, and export drawings and reports; protocol revisions
  2026-07-28, 2025-11-25 and 2025-06-18; every file stays inside the folder given, `--read-only` leaves out the tools
  that write, nothing goes online, and a call can be cancelled ([docs/MCP.md](docs/MCP.md)).
- **Command line**: `export --format dxfR12` works (the name of the format was compared in lower case only).
- The daily soil water balance takes a daily capacity and the day an irrigation year starts (used by the climate risk;
  without them it gives what it gave before), and the default layer of each kind of item moved into the engine.

### Fixes

- **Share links open the shared project again**: the web engine rewrote the address without the `#p=…` before the app
  read it, and a first visit showed the landing page; the link is now taken before the engine and the statistics
  start, a first visit goes straight to the app, and a link pasted into the address bar of the open app (or sent to the
  installed app already open) opens in a tab of its own. The link leaves the address and the history at once.
- A free model under the spending cap no longer divides the cap by a price of zero.

### Not done on purpose

- Anthropic's fast mode (twice the price), local models through an OpenAI-compatible address, and a larger request
  than the app's 30 MB.
- Meta's discounted *Contributor* models (Meta trains on what they receive) and Gemini's long decode beyond 65 536
  output tokens; xAI's server-side tools (web search, X search, code execution) are never turned on.
- The automatic corrections, the scenarios, the technical documents and the online data are not tools of the MCP server
  yet.

## 1.6.1 (2026-11-04)

- **Visit statistics count everyone again**: the site and the app load Google Analytics with its cookies, as up to
  1.5.2 (each page viewed and each start of the app; advertising always denied; the address without the part after the
  `#`). In 1.6.0, whoever did not press *Accept* was counted without cookies, and Google Analytics 4 leaves those visits
  out of its reports until a site has thousands of them a day; the notice did not even show where the app opens by
  itself, so almost nobody was counted. No notice asks any more: *Cookie settings*, at the foot of the pages, opens it,
  and its *Decline* deletes the cookies and stops loading the statistics in that browser (a *Decline* given in 1.6.0 is
  kept). The privacy policy, the FAQ and the manual say so in every language.
- **What's new after an update**: a version without news of its own shows those of the newest version to whoever had
  not seen them yet.

## 1.6.0 (2026-11-02)

A sweep of the whole project, with defects fixed in every area, and new functions in thirteen of them: pump stations
and reservoirs, a daily water balance, power and water analyses, technical documents, block references, a command
palette and more.

### What behaves differently

- **Climate from NASA POWER**: Design → Site climate downloads from NASA POWER by default (free for any use);
  Open-Meteo stays available, marked as non-commercial.
- **Datum of the site**: a georeference names the datum of its place (SIRGAS 2000 in Brazil and the rest of South and
  Central America, ETRS89 in Europe, WGS84 elsewhere) or the one chosen; the `.prj` of the shapefiles and the LandXML,
  IFC and EPANET exports named SIRGAS 2000 everywhere before.
- **Drip areas of the gallery**: the drip and micro-sprinkler areas of the examples take the ground cover of their
  crop (Kr 0.50 to 0.94 instead of 1), so their depths and run times are smaller.
- **Professional title block**: once any of its fields is filled in, the title block is 40 mm tall instead of 30 mm
  and the drawing area of the sheet is 10 mm shorter.
- **Terrain model**: the TIN no longer depends on the order of the items (co-circular and repeated points); elevations
  on such points may change by a few millimetres.
- **Pipe lengths along the ground**: losses and the bill of materials use the length on the slope (2 % more at a 20 %
  slope, 12 % more at 50 %).
- **Editing**: `CO` is now the Copy tool, with a base point (`COPYCLIP` and Ctrl+C copy to the clipboard), and Esc
  ends a polyline keeping what was drawn.

### Engine and hydraulics

- **Pump stations** (*Pump station…* in the Properties of a pump): pumps in parallel or in series, standby units and a
  staged start, with the duty of every pump in every system flow; Select pump makes a station of pumps in parallel.
- **Real operation of the zones** (Design parameters): every zone and pivot also runs at the pressure the mainline
  really delivers to it, in a table of the Mainline tab.
- **Valve pilots**: zone valves and mainline valves can reduce the pressure after them, sustain it before them, or
  both.
- **Sizing**: the pipe class covers the water hammer; on hills with a calculated supply the grade line stays above the
  pipe; high points without an air valve are pointed out; the LP holds the energy balance of every loop.
- **The design over its life** (Mainline menu): the designed project aged (rougher pipes) and clogged (emitters)
  beside the new one.
- **Reservoir or dam** (Properties of a water supply): stage–area–volume curve from the terrain, usable volume, cut,
  days of demand and filling time; its level falls and rises in the 24-hour simulation.
- **Air vessels and flywheels**: an air vessel on a junction of the mainline and a flywheel on a pump take part in the
  transients; the long network analyses show their progress and stop with Cancel.
- **Pump curves** pass through their points when the fitted parabola has a hump; **tapes and spraylines** count from
  the end joined to the submain; **devices drawn on a valve** come after it.
- **Linear programme**: no cycling at degenerate vertices (100 units in 1.5 s instead of 5.5 min), and its iteration
  limit is told apart from an infeasible problem.
- **Water hammer** screened along the path of the water (Michaud); **regulated tape** with a regulator at its inlet;
  motor and drive **efficiency** in the energy; PC emitters below their range act as orifices.
- **New messages**: a zone held below its nominal pressure by a regulator, a pump below its minimum flow, a zone whose
  elevation range exceeds the window, pressure below atmospheric, surplus at a valve that does not regulate.

### Automatic design

- **Trace on the image** (Draw menu, `WAND`): a click inside a field, lawn or pond outlines it on the satellite image
  (georeference and internet needed), with tolerance, smoothing and detail; `V` traces every field of the view.
- **Longest lateral** in the block (B), SUBDIV and LAYOUT dialogs: uphill and downhill, for the flow variation allowed
  and the slope, with what limits it, a warning when the longest one drawn exceeds it and *Use the computed limit*.
- **Fix automatically and Optimise** list every correction and change with a tick box: *Keep only the ticked ones* and
  *Show on the drawing*.
- An area drawn across itself is warned about at once; the quote holds the default depths of the mainline (0.6 m) and
  of the zone pipes (0 = on the surface); tree rings go round ponds and notches; the OFFSET preview is the result.
- Guided blocks cover the whole polygon and warn when the rows pass the radius of the guide's bends; routes share no
  vertices; self-crossing areas split into simple ones; hydrozones never share a valve.
- Fix automatically leaves the decisions (a pump on public mains, new system flows) to you and Optimise works in
  steps; spacing and uniformity warnings from the densogram; previews after a pause, with progress and Cancel.

### Agronomy

- **Design → Agronomy**: daily soil water balance (FAO-56 ch. 8, regulated deficit by stage, relative yield by Ky) and
  irrigation programme (daily window, cycle and soak, seasonal adjustment, programme by station and month, CSV).
- Also there: runoff potential (pivots, linear moves, sprinkler zones), fertigation by stage, uniformity in the field
  (catch cans, depth densogram, CU and DU evaluations) and user crops, with an *Irrigation management* tab in the reports.
- **INMET station files** (CSV or ZIP) in Site climate give the normals and the daily series; the design check
  compares the capacity with the peak demand and the application of the machines with the soil.
- One rule for localised irrigation in every table (Kr by the ground cover), Kc adjusted to the climate and to the
  irrigation interval, station normals, CONAMA 284 ranges as published.
- Warnings for an application rate above what the soil takes in, an ETo off the site climate, a planting date that is
  ambiguous and water too saline for the crop.

### Machines, power and water

- **Pump house electrics** (Design menu): IE3 motor, starting method, feeder by NBR 5410, short circuit by IEC 60909,
  transformer or generator and tariff group, and the supply of the pivots.
- **Solar pumping of the design** (off-grid by IEC 62253, or grid-tied under Brazil's Lei 14.300/2022), deducted from
  the energy cost; **Water quality and filtration**: clogging hazard, filters, chlorine and acid.
- **Several pivots in the property** (Design → Automatic design), **Two-wire system** (Zone menu, decoders in the bill
  of materials), **Traveller lanes** and **Furrows with gated pipe** (Mainline menu).
- Report tab *Power, water and machines*; a corner arm no longer waters a ring twice; linear and arm electrics, a slow
  revolution warning and the current limits of the controllers.

### Technical documents and sheets

- **File → Title block and technical lead**: company, logo, technical lead, council, registration, ART/RRT/TRT, CAR,
  water permit, municipality/state, stage, drawing number and revisions; *Save as my defaults*.
- **Datum** in File → Georeference; a UTM or geographic **coordinate grid** on the sheets; extra **slope** and
  **aspect** sheets.
- **File → Export document package (PDF)**: proposal, water permit and licensing, installation, technical report,
  operation and maintenance, each with cover, contents, numbered sections, drawings and signature.
- **Reports → Technical documents**: water permit table with self-monitoring (ANA Resolutions 1,939/2017 and
  188/2024), descriptive and calculation memorial (written without the AI) and operation and maintenance plan.
- Also there: budget by unit-cost compositions (BDI by TCU Ruling 2622/2013, physical-financial schedule) and
  life-cycle cost (NIST Handbook 135), in PDF, XLSX, CSV or Markdown and in the packages.
- Reports: *Slope by irrigated area* and the standards of the criteria under every table (PDF, CSV, TXT); a check for
  an intake without a flow meter or an hour meter.

### CAD drawing

- **View → Snaps and drawing**: each snap on its own, dynamic input, the touch magnifier and editing while the design
  runs; END, MID, INT… for the next point only (NON clears it).
- Tab fixes the typed length, then the angle, which takes azimuths (A45) and bearings (N45E); field coordinates such
  as `23S 456789 7654321`, `UTM e,n`, `LL -22.5,-47.1` and DMS; pressure in kgf/cm².
- **Layers**: named layer states, LAYISO and LAYUNISO, Move to the current layer; a double click edits a text in
  place; Draw → Dimension style; TOFRONT and TOBACK.
- **Block references** with `{TAG}` attributes, counted in the bill of materials when marked, inserted as a reference
  or as copies, edited in place (BEDIT) and exploded; the block library exports and imports (`.oci-blocks.json`).
- A mixed selection edits one kind of item at a time; drawing and snap settings are kept in this browser; Draw → Field
  photo (by the photo's GPS, the device or a click); Lengthen (`LEN`) and Outline by a click inside (`BO`).
- **File → Compare with…** another tab, a version or a file, and **Bring back the comments of a copy**; versions
  compare and open in a tab.
- **Editing**: Move and Copy with a base point, typed angle, factor and distance, trim and extend to closed outlines,
  circles, arcs and splines, select similar, quick select, lasso, fence and by layer.
- Also: join, explode, fillet, chamfer, stretch, break at two points and convert to area; Measure keeps its result,
  adds lengths and measures areas; a context menu by touch and pen; Backspace deletes the selection.
- **Copies in the browser** go to IndexedDB, written 3 s after the last edit and on closing, recovered item by item;
  Save as, Save as copy and File → Browser storage (download all, ask to keep); Cancel on the progress card.
- A configurable street map server and the terms of every map; pasting between projects keeps the place on the map.

### Files and formats

- **Points import** (CSV, TXT, XYZ, PTS, PNEZD): a wizard with the role of each column, the decimal mark, the
  coordinate system and a preview on the world map that warns about points far away.
- **File → Export drawing → Stake-out points (PNEZD)**; **File → Saved downloaded data** keeps the online DEM and the
  climate on the device.
- **Sheets** of a custom size (and elongated ISO and ANSI ones), layers in the PDF and PDF/A-2b.
- KMZ ground overlays come in as a georeferenced background; survey blocks with an elevation become spot heights;
  DXF/DWG exports carry the hydraulic data (XDATA) and come back as a network.
- Large GeoTIFF, BigTIFF and COG rasters reduced as they are read; polyconic, Albers and Lambert conformal conic
  projections; CJK code pages; a large project link asks before it opens.
- Points without an elevation become markers; DWG units and colours; the CRS of GeoTIFFs; limits for zip bombs and
  exploding blocks; DXF, DWG and LAS read in slices with Cancel; paper space left out.

### Model, catalogues and command line

- **Areas with islands**: Edit → Geometry → Subtract from area (a pond, a building) gives the net area and water, the
  layout keeps out of the island, and DXF/DWG/SHP/KML/GeoJSON carry it; *Remove the islands of the area*.
- **File → Insert project…** merges another `.oci.json` in its place on the ground.
- **Pipes by standard**: ISO 1452, EN 12201, IS 4985 and IS 4984 packs with dated reference prices (source and date in
  the dialog); the catalogue and its CSV in the units of the project (inches, psi, gpm, price per foot).
- **Design parameters → New projects**: where each starting value comes from, *Use these parameters for new projects*
  and *Back to the region's defaults*.
- **Command line**: `import`, `new`, `set`, `pack add` and batches with `--out-dir`; the engine as a package without
  Flutter (`dart tool/engine_package.dart`, `dart compile exe`).
- Files read item by item (unknown fields kept) with a repair report, format version 2 with migrations, a TIN 10 to 25
  times faster, the default catalogue corrected and checked for plausibility, CSV by RFC 4180, `oci validate`,
  `oci schema`.
- Pasting in the engine (items of the same id renamed, prices converted), ASTM inch pipes, ft H₂O, the mains frequency
  of the region; the factory catalogue and your default are restored, loaded or forgotten apart, after a confirmation.

### AI assistant

- **Apply the rest of this task** on the approval card; **Conversations of the project** (list, new, open, delete,
  export, import): `/new` keeps the current conversation, `/clear` deletes it.
- Settings: **Test the connection** to the model (time, cost, limits), **Adjust the effort to each stage**, a notice
  when the app is in the background and system notifications.
- **Costs by step** under every answer, with the share read from the cache; a smaller model reads long attachments
  (`summarize_attachment`).
- It reaches every new function and the editing of the sweep (stretch, fillet, chamfer, break, join, explode, convert
  to area), Save as copy, the browser storage, the terms and server of the maps and ETo from station normals.
- Permissions by setting and effect, the card runs exactly what it showed, its undo steps apart from your edits, one
  conversation per tab, the project's content read as data, the selection pinned while it plans.

### Interface and tutorial

- **Ctrl+K** finds any menu, command or setting (on a phone at the top of ☰); **Help → Manual (F1)** and a **?** in
  the windows and panels; Help → What's new; Help → Report a problem or suggest a feature.
- **View → Interface**: size, high contrast, focus mode (Ctrl+Alt+F), the side panel folded away, its edge dragged to
  any width; a **preview of the sheets** in the PDF and PNG export.
- **Tutorial**: 90 steps in chapters, with tracks on its card, continuing where you stopped, a short track for touch
  screens, quick tracks (drip, landscape, pivot) and AI demonstrations that send nothing; it opens in a tab of its
  own.
- A new tab without a name says *New project* in the language of the moment.
- Numbers in the notation of the language; phone and tablet layouts; interactive reports (sort, filter, copy, CSV,
  find the item); dialogs with a real Cancel; 48 px touch targets and labels; Help → Recent messages.
- **Translations**: report totals, pump curve points and other labels that stayed in English in 17 languages are
  translated; one name per concept (the submain is *linha de derivação* in Portuguese and *portalaterales* in Spanish;
  German calls every emitter *Auslass*), kept by a tested glossary (`tool/i18n/glossary.json`).

### Site and installed app

- **Open with** and share files and photos with the installed app; a second launch goes to the window already open.
- **Fonts** of every script served by the site itself (no request to Google); the **user guide** on the site
  (`/manual/`, `/pt/manual/`).
- **Help → Terms of the data**, with the credits on the sheets and in the report; **View → Base map → Keep the map of
  the area for the field**.
- **Privacy and terms**: the site has a privacy policy and terms of use in every language, linked from the foot of the pages and from Help → About; About also says that a
  qualified professional checks and signs a design made with the app.
- **Visit statistics in Consent Mode**: the pages and the app load Google Analytics in Consent Mode v2 (advertising
  always denied); without consent it sets no cookie and sends notices without cookies (each page and each start of the
  app), and the cookies come only after *Accept* on the notice the pages show once. *Cookie settings* at the foot of
  the pages changes the answer, and declining deletes the cookies.
- **Security**: a Content Security Policy in every page (scripts from the site only, no inline script), a versioned
  hosting configuration (`hosting/firebase.json`) with `Referrer-Policy`, `Permissions-Policy`, revalidation of the
  app files and a permanent redirect from `/en/`; the key warnings say who could read a remembered key.
- **New version notice**: the installed app and a tab left open learn of a new version and offer to reload into it
  (unsaved work goes to the autosave).
- **Smaller offline copy**: the language packs, the PDF fonts and the licence list are kept only once used, so the
  copy kept for offline starts went from about 28 to about 17 MB, and a release no longer downloads every language.
- **One install in every language**: each language page has its own manifest (names, shortcuts and start address in
  that language), with a phone screenshot for the install sheet; `hreflang` also names the bare `pt` and `zh`.
- **Documentation**: a short README with the manual in `docs/manual/` (English and Portuguese), this changelog,
  `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, issue and pull request templates and `CITATION.cff`; the
  editorial rule is tested by hash.
- Translation review by native speakers in a spreadsheet (`tool/i18n_review.dart`); Discussions templates and a social
  image for the repository.

### Engineering

- **End-to-end smoke test** of the production build in Chromium, WebKit and Firefox, also on CI.
- One list of forbidden names (`tool/hooks/banned-names.sha256`) for the test and the pre-commit hook; `test/seams/`
  holds the tests that cross modules.
- **Full browser storage**: versions and projects already saved to a file go first, never unsaved work, and the
  warning stays until a copy fits.
- CI on GitHub Actions with Dependabot, pre-commit hooks, guard tests (design worker, engine purity, brand, site
  date), `tool/release.dart`, PDF fonts rebuilt, a working macOS build, Flutter pinned to 3.47.9, no test reaching the
  network.

## 1.5.2 (2026-10-31)

- The emitters of drip tapes and driplines look the same in every overlay: small dots on the line at the real
  position of each emitter, thinned when zoomed out; only their colour changes (their own pressure in the pressure
  overlay).

## 1.5.1 (2026-10-31)

- The end of a design no longer freezes the app: the automatic copy in the browser is compressed by the browser in
  the background, and the design assistant's messages come ready from the calculation.

## 1.5.0 (2026-10-31)

- A fluid drawing board with tens of thousands of items and hundreds of layers: the drawing is kept between frames,
  a heavy drawing follows pans and zooms as a moved picture, and snaps and grips no longer scan the whole project.

## 1.4.0 (2026-10-30)

- Designs up to 25 times faster with the very same results (an elimination plan for the network solver, indexed
  lookups, zone networks reused).

## 1.3.0 (2026-10-30)

- The AI assistant sees the drawing over the satellite image, outlines fields on the imagery, follows the points and
  lines the user marks on the map, takes dictation, keeps conversations in the browser, reviews a design with
  `/review`, previews a sheet before export and pins field photos with GPS.

## 1.2.0 (2026-10-26)

- The app opens on an empty project with a start screen: where the area is (an address or coordinates) and whether
  to design with the AI assistant; the assistant was reviewed and the site speaks about it.

## 1.1.0 (2026-10-25)

- The optional AI assistant (Claude or GPT with the user's own key) works on the project with the program's tools;
  automatic design (head layout, zoning, routing, field subdivision, pivot fit), hydraulic transients and a light
  theme.

## 1.0.1 (2026-10-19)

- The source code is published under the MIT licence; the site and the app say so and link the repository.

## 1.0.0 (2026-09-22)

- First public version: CAD drawing, hydraulic network, sizing by linear programming, reports, PDF sheets, DXF and
  DWG, the interactive tutorial, the example gallery, offline start and 20 languages.
