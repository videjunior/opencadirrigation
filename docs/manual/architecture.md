# Code architecture

```
bin/oci.dart                command line: import, new, set, pack add, design, analyze, check, validate,
                            export, bom and schema for .oci.json projects, one or many at a time
lib/
  core/                     pure Dart, no Flutter (runs in the worker, in the isolate, the tools and the CLI)
    api.dart                the whole engine in one import (docs/API.md)
    hydraulics/             formulas and solvers
      friction.dart           Hazen-Williams, Darcy-Weisbach (Swamee-Jain, Colebrook, Blasius, laminar,
                              transition), Scobey, Manning
      minor_losses.dart       fitting K, equivalent length, curve h = K·Q^n + C
      emitter.dart            q = k·H^x, wetted radius, fit to a data-sheet table, pressure window, overlap CU
      lateral.dart            step-by-step lateral analysis, maximum length, feed positions
      network.dart            network solver (Global Gradient Algorithm) with emitters, pumps, PRV, PSV,
                              FCV, check valves
      sparse_solver.dart      sparse LDLᵀ with minimum-degree ordering
      pump.dart               pump and system curves, operating point, power, NPSH, CRF, energy
      uniformity.dart         CU, DU, EU, Us, flow variation
      water_hammer.dart       celerity, Joukowsky, critical time
      transient.dart          transients by the method of characteristics (pump trip, air valves,
                              vessels, vapour cavities)
      eps.dart                extended-period simulation: tanks, schedules, patterns, controls, energy
    model/                  data
      geometry.dart           Pt, Bounds, segments, polygons, offsets, convex hull, affine transformations
      entities.dart           drawing and hydraulic entities (JSON, clone, transform, grips, distance)
      catalog.dart            component catalogue and default database, pipe class derating
      catalog_packs.dart      manufacturer packs (in memory) and merging
      currency.dart           currencies, default by language/region, reference exchange rates, price conversion
      project.dart            project: meta, parameters, catalogue, layers, entities, system flows
      terrain.dart, tin.dart  terrain model: Delaunay TIN constrained by breaklines, IDW, contour lines
      slope_map.dart          slope and aspect on a grid
      spatial_index.dart      STR R-tree for culling, selection and snap
      split.dart              splitting of linear entities
      blocks.dart, label_rules.dart, scenario.dart, proposal_settings.dart, site_climate.dart,
      pivot_machine.dart      user blocks, conditional labels, alternatives, quote settings, site climate,
                              pivot machine data
      agronomy_plan.dart, agb_settings.dart, deliverables.dart, title_block.dart, pump_station.dart,
      reservoir.dart, valve_pilot.dart, dim_style.dart, layer_states.dart
                              settings kept in the project since 1.6.0: agronomy plan, power and water,
                              technical documents, title block, pump stations, reservoirs, valve pilots,
                              dimension style, layer states
      area_holes.dart, boundary.dart, lengthen.dart, edit_ops.dart, paste.dart, project_merge.dart,
      project_compare.dart    islands of areas, outline by a click inside, lengthen, geometry edits,
                              paste, insert project, comparison of two copies
      pipe_standards.dart, catalog_check.dart, regional.dart, read_report.dart, schema.dart
                              pipes by standard, catalogue plausibility, defaults by region, tolerant
                              reading with its report, JSON Schema of the project file
    design/                 designer
      network_builder.dart    entities → hydraulic graph (nodes, links, zones, emitter lumping, fittings)
      designer.dart           orchestration: zones, mainline, pressure classes, telescoping, flushing,
                              water hammer, machines, wiring, BOM
      lp.dart, lp_sizing.dart dense two-phase simplex and the sizing formulation
      block_generator.dart    lateral blocks (straight and guided) and sprinkler grids
      auto_layout.dart, zoning.dart, routing.dart, templates.dart, field_subdivision.dart,
      tree_rings.dart, pivot_fit.dart, vegetation.dart
                              automatic design: heads, zones, pipe and mainline trees, turf templates,
                              blocks, drip rings, pivot fit, vegetation from aerial imagery
      pivot.dart              centre pivot and linear move hydraulics
      mechanised.dart, pivot_package.dart, corner_arm.dart, vri.dart, pivot_electrical.dart
                              sprinkler package and timer, corner arm, variable rate, pivot electrical
      traveller.dart, surface_irrigation.dart, gated_pipe.dart
                              hose-reel travellers, furrows, borders and basins, gated pipe
      fittings.dart           automatic fitting selection
      pump_selection.dart     pump and motor choice
      agronomy.dart           ETc, water balance, controller programme
      climate.dart, crops.dart, soils.dart, effective_rain.dart, irrigation_requirement.dart,
      area_requirement.dart   FAO-56 ETo and crops, USDA soils, effective rain, requirement tables
      solar_pumping.dart, wetted_bulb.dart, water_budget.dart
                              PV pumping, drip wetted bulb, landscape water budget
      management.dart         demands of zones, pivots and stations, automatic system flows
      valve_in_head.dart      valve-in-head stations
      densogram.dart          water applied by the sprinklers as drawn, uniformity per area, wind
      electrical.dart         valve wiring: routes, stations, wire sizes for the solenoid voltage
      two_wire.dart, wire_routing.dart
                              two-wire (decoder) sizing, wire routes along the trenches
      transient_analysis.dart, air_valves.dart
                              transients of the mainline, air valves (AWWA M51), 24-hour simulation
      network_ops.dart, on_demand.dart, tariff.dart, energy_grouping.dart, criticality.dart,
      calibration.dart, fertigation.dart
                              operation: Clément flows, tariff schedule, energy grouping, N−1,
                              calibration, fertigation
      proposal.dart           commercial quote, trenches, payback, construction schedule
      soil_water_balance.dart, irrigation_programme.dart, runoff_potential.dart, system_capacity.dart,
      catch_cans.dart, fertigation_stages.dart, agr_tables.dart
                              daily water balance, controller programme, runoff, capacity against the
                              peak, field uniformity, fertigation by stage, their report tables
      pump_house.dart, solar_design.dart, water_quality.dart, multi_pivot.dart, field_machines.dart,
      agb_design.dart, agb_reports.dart
                              pump house electrics, solar pumping, water quality, several pivots,
                              traveller lanes and furrows, run as a step of the design
      permit.dart, memorial.dart, om_plan.dart, budget.dart, life_cycle.dart, report_standards.dart,
      slope_report.dart       technical documents, the standards of the reports, slope by area
      life_scenarios.dart, reservoir.dart, analysis_control.dart, lateral_limit.dart, region_trace.dart
                              ageing and clogging, reservoir study, progress and cancel of the analyses,
                              longest lateral, outlines traced on aerial imagery
      design_check.dart       design check
      advisor.dart            problems explained, impossible settings, corrections that apply
      auto_fix.dart           corrections, fix automatically, optimisation
      results.dart, report_tables.dart  serialisable results and report tables
    io/                     format readers and writers
      dxf.dart, dwg.dart, dgn.dart, kml.dart, shp.dart, geojson_reader.dart, gpx.dart, landxml.dart,
      las.dart, epanet_inp.dart, points_csv.dart, point_grid.dart, geoimage.dart, dem_tiff.dart
                              readers (the EPANET, GPX and LandXML files also write)
      cad_drawing.dart, cad_export.dart, dxf_r2000.dart, dwg_writer.dart
                              R2000 DXF and DWG with native entities
      pdf_reader.dart, pdf_reader_fonts.dart, pdf_reader_images.dart, pdf_import.dart
                              PDF plans as an underlay
      plot.dart, pdf.dart, pdf_sheet.dart, sheet_set.dart, sheet_canvas.dart, details.dart,
      plot_charts.dart, svg.dart
                              plot scene, PDF writer, sheet sets, construction details, charts, SVG
      fonts/                  TrueType reader and subsetter, OpenType shaper (Arabic, Indic), bidi,
                              Unicode data, the PDF font registry
      shp_writer.dart, geo_export.dart, ifc.dart, xlsx.dart, catalog_io.dart, project_export.dart
                              shapefile, KML/GeoJSON, IFC 4, Excel, catalogues, export dispatch
      geo.dart, datum.dart    UTM, datums (SIRGAS 2000, SAD 69, Córrego Alegre), the datum of the site,
                              projections (Albers, Lambert conformal conic, polyconic), CRS recognition
      drawing_import.dart, import_async.dart, work_slicer.dart, safe_archive.dart, tiff_raster.dart,
      cad_xdata.dart, codepages.dart, typed_geo.dart, stakeout.dart, data_cache.dart, data_credits.dart
                              drawings into a project (also for the command line), reading in slices,
                              zip limits, large TIFFs, hydraulic XDATA, code pages, typed field
                              coordinates, stake-out points, downloads kept, third-party credits
      doc_package.dart, doc_pdf.dart, doc_sections.dart, tech_doc.dart, tech_doc_sections.dart,
      title_block_sheet.dart, sheet_grid.dart, sheet_theme.dart, sheet_check.dart, icc_srgb.dart
                              document packages, technical documents, professional title block,
                              coordinate grid, slope and aspect sheets, sheet check, sRGB profile of PDF/A
      dem_online.dart, climate_online.dart, share_link.dart
                              online elevation and climate, projects in a link
    ai/                     optional AI assistant, two companies behind one interface
      llm.dart                models with their tiers and list prices, tokens and cost, errors, the
                              client every company implements
      llm_formats.dart        conversion of messages, tools and results to each company's format
      claude_api.dart         Anthropic Messages API: streaming, adaptive thinking, effort, caching,
                              refusal fallback, task budgets, compaction, clearing of old tool results
      openai_api.dart         OpenAI Responses API: streaming, function tools, reasoning effort,
                              store: false, compaction
      agent_loop.dart         the agent loop: tools, approvals by mode, step limit, spending cap
      project_context.dart    the project data sent with a message
    units.dart              units (metric/US), water viscosity, typed tables
    translate.dart          translation hook so reports and plots label their output without Flutter
    i18n/language_packs.dart registry of the language packs (strings, tutorial, catalogue names)
  app/                      Flutter
    state/                  ProjectController (project, selection, camera, undo, spatial index, calculation),
                            Workspace (tabs and clipboard), DesignRunner (worker/isolate/thread)
    canvas/                 CadCanvas, CadPainter, Camera, Snapper, base map
    tools/                  drawing, editing and hydraulic tools, typed points, block insertion
    keys/                   shortcut dispatcher and native listener
    widgets/                menus, palette, panels, reports, charts, dialogs, compact layout, and
                            ai/: the docked AI panel and its views (conversation, data sent, settings)
    ai/                     the agent of a tab: 75 tools and 205 operations over the controller and
                            the engine (agent_tools*, agent_ops*, ops_*, op_parts/ by area), the
                            coverage map (ai_coverage.dart, coverage_parts/), the system prompt, the
                            manual and the playbooks,
                            vision (pictures, tiles, terrain), transports (fetch, HttpClient),
                            approvals, rewind and undo
    tutorial/               interactive tutorial
    io/                     files, preferences, HTTP, local storage, HTML document, external links,
                            GPS, PDF fonts, PNG export of a sheet
    actions.dart            file, clipboard and export actions shared by menus, palette and aliases
    examples.dart           example gallery
    i18n.dart               pt/en/es text table (with its parts by area in i18n_parts/), language list
                            and on-demand loading of the packs
    i18n_assets.dart        reads assets/i18n/<code>.json for the chosen language
    shortcuts.dart          command aliases (pt/en/es) and the shortcut table
    theme.dart              dark and light palettes (CadPalette, 76 colour tokens read through Cad.*),
                            the CAD colour rule of the light canvas, theme switching (CadThemeHost)
    version.dart            generated app version (tool/gen_version.dart)
  worker/design_worker.dart Web Worker entry point
assets/                     language packs (i18n/) and the Noto font subsets of the PDFs (fonts/)
catalogs/                   manufacturer packs (JSON) and index
docs/                       technical study, the engine API (API.md, API.pt-BR.md) and what the AI
                            reaches (AI_TOOLS.md, generated)
examples/                   example projects, one folder per interface language (20)
tool/                       generators: site (with the user guide), catalogues, examples, brand, version,
                            service worker; worker and web builds; fonts and shaping fixtures
                            (tool/fonts); the engine as a package without Flutter (engine_package.dart);
                            the release checklist (release.dart); translation review (i18n_review.dart);
                            the pre-commit hook and the list of forbidden names (hooks/); the
                            end-to-end smoke test (e2e/)
test/                       engine, model, format and interface tests; guards/ (generated files, worker,
                            engine purity, network), seams/ (tests across modules), goldens/, web/
web/                        pages, manifest, icons, robots, sitemap, compiled worker, offline start
                            (sw.js, offline.js)
```

## Design decisions

- **Pure Dart engine.** `lib/core` does not import Flutter, so it runs in the Web Worker, in the
  isolate, in `dart run` (tools and the command line) and in fast tests. The interface only builds
  requests and shows results.
- **One controller per project.** `ProjectController` holds the project, the selection, the
  camera, the undo stack (entity snapshots), the spatial index and the calculation state. Every edit
  goes through `mutate`, which takes the snapshot, marks the project dirty, invalidates results and
  the index, notifies the interface and schedules the autosave.
- **Calculation off the thread.** The project is serialised to the worker; the worker returns the
  results and the resized entities; an edit counter discards results of a project that changed
  while it was being calculated.
- **Spatial index.** STR-packed R-tree rebuilt on every edit; painting queries only the visible
  window, and selection, snap and window selection query the index (microsecond queries with tens
  of thousands of entities).
- **Drawing on screen.** The canvas keeps its drawing between frames (`SceneCache`): it is recorded
  again only when something it shows changes (an edit, the selection, the view, the base map, the
  results), so moving the cursor repaints only the snap marker, the tool preview and the item under
  the cursor over a picture of the scene. A scene that takes long to draw follows a pan or a zoom as
  a moved picture and is drawn sharp once the view rests. The painter gathers its drawing calls by
  paint (a few hundred calls for tens of thousands of items) and leaves out vertices closer than a
  pixel; lines no wider than a device pixel are drawn as hairlines and wider ones segment by segment
  (in the browser a wide stroked path is rasterised on the CPU), and a view packed with linework on
  a high-density screen draws its 1 px lines one device pixel wide. The status bar alone listens to
  the cursor coordinates, so the window is not rebuilt on every move.
- **Own formats in pure Dart.** Readers and writers of DWG, PDF (with its fonts and text shaping),
  XLSX, SHP, GeoTIFF, LAS, IFC etc. do not depend on native libraries, which keeps the app 100 %
  web.
- **Centralised texts.** All interface strings are keys of `i18n.dart`, with the Portuguese, English
  and Spanish texts compiled in and the other 17 languages in the packs of `assets/i18n`; the engine
  returns codes (`velocity_exceeded:e12`) that the interface translates. Every test file fails when
  the interface asks for a key the table does not have (`test/flutter_test_config.dart`), which
  would otherwise show the key itself on screen.
- **The AI uses the program, not a copy of it.** The assistant's tools are thin wrappers over the
  controller and the engine, every change goes through `mutate` (one undo group per answer), and
  a coverage map routes every user-reachable function to a tool, an operation, a command or a
  setting. The two companies sit behind one interface (`llm.dart`), with the format conversion in
  one place (`llm_formats.dart`) and one agent loop; the request code takes the HTTP exchange as a
  parameter, so the tests run it against scripted fakes.
