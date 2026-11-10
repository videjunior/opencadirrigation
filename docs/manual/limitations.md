# Known limitations and roadmap

- **Looped networks**: the LP holds the energy balance of every loop for the flows it sizes for and
  is solved again with the flows of the new sizes until they settle; when they do not, a note says
  the result is an approximation; the final analysis checks, and the greedy method is the safe
  alternative.
- **Network solver**: pressure-compensating emitters in grossly undersized networks (flows many
  times what the pipes can carry) may still fail to converge; the design then reports
  `not_converged` instead of figures.
- **Transients**: the analysis covers the mainline of each system flow, with the zones seen from it
  as orifices at their valves; friction is quasi-steady (a constant factor per pipe); air vessels go
  on junctions of the mainline only.
- **24-hour simulation**: the only level that changes over the day is that of the reservoir or dam
  behind a water supply; tanks inside a network, patterns and level controls exist in the engine's
  extended-period simulation ([docs/API.md](../../docs/API.md)) but not in a project.
- **Electrical**: the design wires the valves conventionally (a station conductor per valve and a
  shared common) with 24 V AC solenoids, or, with Zone → Two-wire system on, as a two-wire (decoder)
  system whose decoders and cable replace the station wires in the bill of materials. The pump house
  electrics follow NBR 5410 (as IEC 60364-5-52) and IEC 60909 with typical power factors of motors and
  short-circuit impedances of transformers.
- **DWG and DXF**: the reader covers the typical entities of a plan (lines, polylines, circles,
  arcs, ellipses, splines, hatches, solids, leaders, points, texts, blocks and dimensions), with
  R13/R14 read in part; the writers produce R2000 only (DWG with colour indices; true
  colours in the DXF), and pictures go out as their frame, without the raster.
- **PDF plans**: shadings, pattern fills (drawn grey), transparency groups, annotations and Type 3
  glyph drawings are not interpreted; clipping is approximated by rectangles; filled areas come in
  as outlines; encrypted files and JPEG 2000 or JBIG2 images are left out; the work of a page is
  capped, and a truncated page says so.
- **Other files**: compressed LAZ clouds and DGN V8 are refused by name; JPG, PNG and other pictures
  above 100 million pixels are refused (TIFF rasters, BigTIFF and cloud-optimised GeoTIFF included,
  are read block by block and reduced, up to 4 billion pixels); above 40 000 samples the TIN keeps the
  survey and thins the downloaded elevation model.
- **Datums**: SAD 69 and Córrego Alegre are shifted with three-parameter translations (a few metres
  of accuracy); a grid-based transformation is not applied.
- **Densogram**: one spray profile for every head without a measured profile (chosen in the
  dialog: sprays are closer to uniform, single-nozzle impact sprinklers to triangular); wind is a
  first-order drift of the calm-air pattern, not a substitute for windy-day measurements.
- **Agronomy and field models**: soil values are typical ones for the texture class; the wetted
  bulb formula comes from two soils and two emitters and extrapolates outside them; the corner arm
  assumes level ground, a rigid arm and a convex guide path; surface irrigation uses the volume
  balance, not a hydrodynamic model.
- **Vegetation detection**: plain image processing of the colours and texture of one image: dry
  lawns, deep shade or green roofs can be misread, so the outlines need a check; the imagery's terms
  of use apply.
- **Crop rows from the image**: straight, evenly spaced rows seen with at least about three pixels
  of the imagery per spacing (rows closer than about 1–2 m are not seen on most free imagery); rows
  that bend along the contours give an average direction; which band is the crop is decided by
  colour and may need *Rows on the other band*; the plant spacing is rarely visible at 0.3–0.6 m a
  pixel and is then left unknown; shadows count as canopy. It runs on the page with pauses and a Stop
  button, not in a worker, and has been checked in tests and on real imagery outside the app, not in
  a real browser.
- **Climate risk over the years**: reanalysis cells of about 50 km smooth the local extremes; only the
  first crop cycle of an area is evaluated; the summary kept in the project does not follow later
  changes of the design (run it again); the analysis runs on the page, so a project with many areas
  may hold it for a second or two; serial correlation is not removed from the trend test. A full
  download from the live NASA POWER service through the app and the dialog in a real browser were
  not tried (two real answers are parsed in the tests).
- **Irrigation forecast**: the radiation of MET Norway's days comes from the temperature range (FAO-56
  eq. 50, kRs 0.16 everywhere, 0.19 would suit coastal sites), checked against Open-Meteo's ETo on
  five days of one site only; days are local solar days, which can differ by an hour or two from the
  clock; the forecast is not saved in the project nor in the main report. Browsers call MET Norway
  directly, which its terms allow for low-volume sites; a much larger traffic would need a proxy. The
  dialog and its PDF export were not tried in a real browser.
- **Programme on the plan**: the steady state of each group, no transients at starts and stops;
  overlapping groups are added, not solved together; the reservoir level comes from the continuity
  of its volume along the programme, not from the 24-hour simulation; the calendar uses the run
  times of one month, floating time and no alarms; a period longer than 28 days is cut. Not tried in
  a real browser.
- **Design scorecard**: equal weights, linear compliance shares and all-or-nothing counts; the
  scores compare designs and are not a certification; the q_var bands are the program's working
  bands (see [Calculation and sizing](calculation.md#design-scorecard)); the exports from the dialog
  were not tried in a real browser.
- **Curves from a picture**: affine calibration only (a photo taken at an angle reads approximately);
  one curve of each kind per picture; the shaft power is assumed (P2); pasting a picture in Safari
  and the wheel and pinch in a real browser were not tried.
- **MCP server**: tested on macOS (the path rules of Windows are written but untested); `set_project`
  checks the keys, types and choices of the settings but not their ranges (the design check reports
  impossible settings); exports and reports are not written atomically, so a call cancelled midway
  may leave a partial file; a hard link inside the root, or a link changed between the check and
  the use, is not seen; the engine package ships without the example projects.
- **Automatic copy in the browser**: about 64 MB per project after compression in IndexedDB (about
  3.5 MB where only localStorage is there); larger projects keep only their file (the app says so
  once). The copies stay in this browser on this device and are not a backup.
- **Collaboration**: no simultaneous editing; projects are shared by the `.oci.json` file or by a
  link, which leaves the images and results out and is refused when the project is too large; a
  reviewed copy is compared with File → Compare with… and its comments brought back with File →
  Bring back the comments of a copy.
- **Performance**: projects with hundreds of tapes per zone take a few seconds per zone; the
  flushing step is the heaviest.
- **Offline start**: checked by the end-to-end smoke test in Chromium and, where the browser build
  can run the check, in the WebKit and Firefox builds of Playwright (a check a build cannot run is
  reported as skipped); base maps, online elevation and climate not kept on the device, the weather
  forecast, catalogues by URL and the AI assistant need the network. The share links (first visit,
  returning visit, pasted into the open app, offline) were checked by that smoke test in Chromium
  only before the release; WebKit and Firefox run it on CI.
- **Technical documents**: the water permit table and the budget by compositions follow Brazilian
  practice (ANA resolutions, the BDI ranges of TCU Ruling 2622/2013; rivers and aquifers under state
  control follow the state agency); the starting hourly costs of the budget and the life and
  maintenance of the parts in the life-cycle cost are reference values to replace by local ones.
- **Native mobile**: the `android/` and `ios/` folders are Flutter's templates and are neither
  built nor tested; phones and tablets use the web app.
- **AI assistant**: needs the network and an account with API credit at one of the six companies
  (Claude Fable 5.2 also 30-day data retention; the free tiers of Google and the free models of
  OpenRouter have their companies' limits); in the browser a rejected OpenAI key shows as a
  network failure, since OpenAI's error answers carry no CORS header, and the page cannot read Meta's
  request id and rate limits nor OpenRouter's waits (the desktop app can); reaching the six APIs from
  a page was checked with a made-up key in Chrome 157, Firefox 157 and WebKit 27.2 (the engine of
  Safari) on 2026-11-10: the answer to a rejected key is readable everywhere but at OpenAI; the
  models of Google, xAI, Meta and OpenRouter are not summarised when a conversation grows long;
  pictures do not ask for
  approval although they download base-map tiles; positions read off pictures are approximate; the
  analyses it runs (transients, 24-hour simulation and the like) run on the interface thread;
  conversations never go into the project file nor into share links, but they stay in this
  browser (the 24 most recently saved, with their pictures and small attachments) until
  *Keep conversations in this browser* is turned off, which also deletes them: on a shared computer,
  turn it off or clear the site data. It was tested against scripted fakes of the six APIs, not
  against the live services: the four clients added in 1.7.0 (Google, xAI, Meta, OpenRouter) were
  written from each company's documentation of 2026-11-10 and have never been run with a real key,
  so a format a company changed or documented loosely may still fail. Its answers can be wrong like
  any model's, and a second opinion is another model's view, not a check: changes go through the
  approval, undo and rewind of the [AI assistant](ai-assistant.md), and the design should be checked.

Suggested roadmap: storage tanks inside a network of a project; additional community catalogues;
the offline start checked in Safari itself; automated browser tests for runtime language switching;
the four new AI clients tried against the live services; a four-corner (perspective) calibration of
photographed charts; the automatic corrections, the scenarios and the online data as tools of the MCP
server.
