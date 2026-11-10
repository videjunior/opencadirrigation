/// The OpenCADIrrigation engine in one import: projects and their entities,
/// the catalogue, the designer and its results, the hydraulic solvers
/// (steady state, extended period, transients), the design modules (layout,
/// agronomy, mechanised machines, electrical…), the report tables and every
/// file reader and writer. Pure Dart: it runs in the Dart VM, in a Web Worker
/// and in Flutter alike. See docs/API.md.
///
/// ```dart
/// import 'package:opencadirrigation/core/api.dart';
///
/// final project = Project.fromJsonString(text);
/// final results = Designer(project).designAll();
/// ```
///
/// Importing the individual libraries (`core/model/project.dart`,
/// `core/design/designer.dart`, …) works as well and is what the app does.
/// Left out here: the internals of the PDF text shaping (`io/fonts/*` except
/// pdf_fonts.dart), the sparse matrix solver behind the network solver and
/// the tables of the East Asian code pages (`io/codepages_cjk_data.dart`, a
/// library codepages.dart loads on demand: exported here, it would be part
/// of every program that imports this file)
/// (test/core/api_exports_test.dart keeps the list complete; the parts of a
/// library come with it).
library;

export 'ai/agent_loop.dart';
export 'ai/claude_api.dart';
export 'ai/image_prep.dart';
export 'ai/llm.dart';
export 'ai/llm_formats.dart';
export 'ai/openai_api.dart';
export 'ai/project_context.dart';
export 'design/advisor.dart';
export 'design/agronomy.dart';
export 'design/air_valves.dart';
// 1.6.0 MOT
export 'design/analysis_control.dart';
export 'design/area_requirement.dart';
export 'design/area_water.dart';
export 'design/auto_fix.dart';
export 'design/auto_layout.dart';
export 'design/block_generator.dart';
export 'design/calibration.dart';
export 'design/climate.dart';
export 'design/corner_arm.dart';
export 'design/criticality.dart';
export 'design/crops.dart';
export 'design/densogram.dart';
export 'design/design_check.dart';
export 'design/designer.dart';
export 'design/effective_rain.dart';
export 'design/electrical.dart';
export 'design/energy_grouping.dart';
export 'design/fertigation.dart';
export 'design/field_subdivision.dart';
export 'design/fittings.dart';
export 'design/gated_pipe.dart';
export 'design/irrigation_requirement.dart';
export 'design/life_scenarios.dart';
export 'design/lp.dart';
export 'design/lp_sizing.dart';
export 'design/management.dart';
export 'design/mechanised.dart';
export 'design/model_checks.dart';
export 'design/network_builder.dart';
export 'design/network_ops.dart';
export 'design/on_demand.dart';
export 'design/pivot.dart';
export 'design/pivot_electrical.dart';
export 'design/pivot_fit.dart';
export 'design/pivot_package.dart';
export 'design/proposal.dart';
export 'design/pump_selection.dart';
export 'design/region_trace.dart';
export 'design/report_tables.dart';
export 'design/report_tables_mot.dart';
export 'design/reservoir.dart';
export 'design/results.dart';
export 'design/results_mot.dart';
export 'design/routing.dart';
export 'design/soils.dart';
export 'design/solar_pumping.dart';
export 'design/surface_irrigation.dart';
export 'design/tariff.dart';
export 'design/templates.dart';
export 'design/transient_analysis.dart';
export 'design/traveller.dart';
export 'design/tree_rings.dart';
export 'design/two_wire.dart';
export 'design/valve_in_head.dart';
export 'design/vegetation.dart';
export 'design/vri.dart';
export 'design/water_budget.dart';
export 'design/wetted_bulb.dart';
export 'design/wire_routing.dart';
export 'design/zoning.dart';
export 'hydraulics/emitter.dart';
export 'hydraulics/eps.dart';
export 'hydraulics/friction.dart';
export 'hydraulics/lateral.dart';
export 'hydraulics/minor_losses.dart';
export 'hydraulics/network.dart';
export 'hydraulics/pump.dart';
export 'hydraulics/transient.dart';
export 'hydraulics/uniformity.dart';
export 'hydraulics/water_hammer.dart';
export 'i18n/language_packs.dart';
export 'io/cad_drawing.dart';
export 'io/cad_export.dart';
export 'io/cad_xdata.dart';
export 'io/catalog_io.dart';
export 'io/climate_online.dart';
export 'io/codepages.dart';
export 'io/data_cache.dart';
export 'io/datum.dart';
export 'io/dem_online.dart';
export 'io/dem_tiff.dart';
export 'io/details.dart';
export 'io/dgn.dart';
export 'io/drawing_import.dart';
export 'io/dwg.dart';
export 'io/dwg_writer.dart';
export 'io/dxf.dart';
export 'io/dxf_r2000.dart';
export 'io/epanet_inp.dart';
export 'io/fonts/pdf_fonts.dart';
export 'io/geo.dart';
export 'io/geo_export.dart';
export 'io/geoimage.dart';
export 'io/geojson_reader.dart';
export 'io/gpx.dart';
export 'io/icc_srgb.dart';
export 'io/ifc.dart';
export 'io/image_decode.dart';
export 'io/import_async.dart';
export 'io/kml.dart';
export 'io/landxml.dart';
export 'io/las.dart';
export 'io/pdf.dart';
export 'io/pdf_import.dart';
export 'io/pdf_reader.dart';
export 'io/pdf_sheet.dart';
export 'io/plot.dart';
export 'io/plot_charts.dart';
export 'io/point_grid.dart';
export 'io/points_csv.dart';
export 'io/project_export.dart';
export 'io/safe_archive.dart';
export 'io/share_link.dart';
export 'io/sheet_canvas.dart';
export 'io/sheet_check.dart';
export 'io/sheet_set.dart';
export 'io/shp.dart';
export 'io/shp_writer.dart';
export 'io/stakeout.dart';
export 'io/svg.dart';
export 'io/tiff_raster.dart';
export 'io/work_slicer.dart';
export 'io/xlsx.dart';
export 'io/xml_text.dart';
export 'model/area_holes.dart';
export 'model/blocks.dart';
export 'model/catalog.dart';
export 'model/catalog_check.dart';
export 'model/catalog_packs.dart';
export 'model/currency.dart';
export 'model/edit_ops.dart';
export 'model/entities.dart';
export 'model/geometry.dart';
export 'model/label_rules.dart';
export 'model/paste.dart';
export 'model/pipe_standards.dart';
export 'model/pivot_machine.dart';
export 'model/project.dart';
export 'model/project_merge.dart';
export 'model/proposal_settings.dart';
export 'model/pump_station.dart';
export 'model/read_report.dart';
export 'model/reservoir.dart';
export 'model/regional.dart';
export 'model/scenario.dart';
export 'model/schema.dart';
export 'model/site_climate.dart';
export 'model/slope_map.dart';
export 'model/spatial_index.dart';
export 'model/split.dart';
export 'model/terrain.dart';
export 'model/tin.dart';
export 'model/valve_pilot.dart';
export 'translate.dart';
export 'units.dart';
// 1.6.0 PRD: title block, coordinate grid, thematic sheets, standards, document packages
export 'design/report_standards.dart';
export 'design/slope_report.dart';
export 'io/doc_package.dart';
export 'io/doc_pdf.dart';
export 'io/doc_sections.dart';
export 'io/sheet_grid.dart';
export 'io/sheet_theme.dart';
export 'io/title_block_sheet.dart';
export 'model/title_block.dart';

// 1.6.0 PRB: the technical documents (permit table, memorial, operation and
// maintenance plan, budget by compositions, life-cycle cost)
export 'design/budget.dart';
export 'design/life_cycle.dart';
export 'design/memorial.dart';
export 'design/om_plan.dart';
export 'design/permit.dart';
export 'io/tech_doc.dart';
export 'io/tech_doc_sections.dart';
export 'model/deliverables.dart';

// 1.6.0 AUT+: the longest lateral a block can have
export 'design/lateral_limit.dart';

// 1.6.0 AGB: pump house electrics, solar pumping, water quality, two-wire,
// several pivots, travelling guns and furrows
export 'design/agb_design.dart';
export 'design/agb_reports.dart';
export 'design/field_machines.dart';
export 'design/multi_pivot.dart';
export 'design/pump_house.dart';
export 'design/solar_design.dart';
export 'design/water_quality.dart';
export 'model/agb_settings.dart';

// 1.6.0 AGR+: daily soil water balance, runoff, capacity, the irrigation
// programme, field uniformity, fertigation by stage, user crops, INMET files
export 'design/agr_tables.dart';
export 'design/catch_cans.dart';
export 'design/fertigation_stages.dart';
export 'design/irrigation_programme.dart';
export 'design/runoff_potential.dart';
export 'design/soil_water_balance.dart';
export 'design/system_capacity.dart';
export 'io/inmet_csv.dart';
export 'model/agronomy_plan.dart';

// 1.6.0 CAD+: typed coordinates, the outline by a click inside, dimension
// style, layer states, lengthen, comparing two projects
export 'io/typed_geo.dart';
export 'model/boundary.dart';
export 'model/dim_style.dart';
export 'model/layer_states.dart';
export 'model/lengthen.dart';
export 'model/project_compare.dart';

// 1.6.0 SIT+: the credits of the third-party data in a project
export 'io/data_credits.dart';

// 1.7.0 FCT: the irrigation forecast from the weather forecast of the site
export 'design/irrigation_forecast.dart';
export 'io/forecast_online.dart';
