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
  reported as skipped); base maps, online elevation and climate not kept on the device, catalogues by
  URL and the AI assistant need the network.
- **Technical documents**: the water permit table and the budget by compositions follow Brazilian
  practice (ANA resolutions, the BDI ranges of TCU Ruling 2622/2013; rivers and aquifers under state
  control follow the state agency); the starting hourly costs of the budget and the life and
  maintenance of the parts in the life-cycle cost are reference values to replace by local ones.
- **Native mobile**: the `android/` and `ios/` folders are Flutter's templates and are neither
  built nor tested; phones and tablets use the web app.
- **AI assistant**: needs the network and an account with API credit at Anthropic or OpenAI
  (Claude Fable 5.1 also 30-day data retention); in the browser a rejected OpenAI key shows as a
  network failure, since OpenAI's error answers carry no CORS header; pictures do not ask for
  approval although they download base-map tiles; positions read off pictures are approximate; the
  analyses it runs (transients, 24-hour simulation and the like) run on the interface thread;
  conversations never go into the project file nor into share links, but they stay in this
  browser (the 24 most recently saved, with their pictures and small attachments) until
  *Keep conversations in this browser* is turned off, which also deletes them: on a shared computer,
  turn it off or clear the site data. It was tested against scripted fakes of both APIs, not
  against the live services. Its answers can be wrong like any model's: changes go through the
  approval, undo and rewind of the [AI assistant](ai-assistant.md), and the design should be checked.

Suggested roadmap: storage tanks inside a network of a project; additional community catalogues;
the offline start checked in Safari itself; automated browser tests for runtime language switching.
