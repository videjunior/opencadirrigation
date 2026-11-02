# Reports, plotting and export

## Reports panel

Tabs: zone summary, pipes, emitters, mainline and duties (with the devices), bill of materials,
water requirements, hydraulic grade line (chart of the selected pipe, lateral or valve, with the
allowable pressure band), messages, profile (terrain along a path, with pipe and grade line),
flushing, water hammer, agronomy (ETc, readily available water, interval, depths, hours per event),
schedule (controller calendar per system flow), pivots and pivot spans, electrical (station, route
and wire length, station and common wire, valves open together and solenoid voltage of every valve;
stations used, common length and peak current of every controller), quote, trenches (volumes and
the construction schedule), materials by sector, comments, revisions, alternatives, crop
requirement (with the licensing category), pivot package (nozzle chart and timer), arm, VRI and
electrical, and valve-in-head stations. Tables are virtualised, with columns measured from their
content, and are the basis of every exporter, so PDF, Excel and CSV show the same numbers.

## PDF sheets

File → Export drawing → PDF opens the plot options: size (A4 to A0, Letter, Tabloid), orientation,
scale (automatic or fixed), margin, wetted radii, labels, layer legend, bill of materials on the
sheet, the base map of the screen under the drawing (with its credit) and attached report pages.
A PDF can hold a **set of sheets**: one sheet, or an overview plus one sheet per zone or per
irrigated area (each fitted to its subject with its own materials, the other zones in grey or
hidden), and the current screen view as an extra sheet at its own scale; then **construction
details** (trench, thrust block, valve box, sprinkler riser and swing joint, drip line connection,
air valve, filter station, pump suction) drawn with the design's own pipes, depths, models and
pressures; and **charts** (the mainline grade line of every system flow, the terrain profile and
the pump curves with their duty points). Revision clouds and open comments print on the sheets, and
the revision table lists them under the legend. The scene is built in "paper space": pens, symbols
and texts in paper millimetres, so that 1:500 and 1:2000 are equally legible. The title block
carries the project details, the north arrow and the scale bar.

The PDF writer is our own (PDF 1.4, Flate compression), with no native dependencies: the text
Helvetica can show stays in Helvetica, and any other script (Cyrillic, Greek, Vietnamese, Arabic,
Urdu, Hindi, Marathi, Bengali, Punjabi, Telugu, Chinese, Japanese) is set with embedded subsets of
the bundled Noto fonts, shaped and ordered (bidirectional text) by the app itself, so copy and
search give the text back. Images are embedded (JPEG passed through, other images with their
transparency) and downsampled for the size they are printed at. The same sheet exports as **PNG**
(File → Export drawing → PNG, 96 to 300 dpi, about 40 megapixels at most).

## Commercial quote and alternatives

Design → Commercial quote… turns the bill of materials into a quote: sale prices with the margin,
labour, trench excavation (volumes from the buried pipes and the trench settings), extra lines,
discount, taxes and freight, validity and terms; payback, net present value and internal rate of
return from a yearly benefit; a construction schedule from the crews and their output per day; the
FINAME codes (financing by the Brazilian development bank BNDES) of the items that have one. Design
→ Design alternatives… keeps named copies of the project with their key figures, compares them side
by side and restores one in one undo step.

## Exports

| Format | Contents | Notes |
|---|---|---|
| DXF | R2000 (AC1015) with native entities: polylines with arcs, splines, hatches, dimensions, leaders, multiline text; symbols and hydraulic items as blocks with attributes (NAME, ITEM, NOZZLE, ZONE, STATIONS); layers with true colours and dashed linetypes; user blocks as block definitions | Validated with ezdxf and LibreDWG and re-read by the app's reader |
| DXF R12 | The plain primitives of the earlier export, one text per line | For older programs |
| DWG | R2000 (AC1015), the same native drawing (colour indices only) | Our own writer, validated with LibreDWG and re-read by the app's reader |
| PDF | Sheet sets with title block, legend, north arrow, scale bar, details, charts and, optionally, reports | Every interface script |
| PNG | The sheet as an image, 96–300 dpi | |
| SVG | Sheet in millimetres, one group per layer, images embedded | Browsers, Inkscape |
| KML / KMZ | Folders per layer, WGS84 coordinates | Google Earth; needs a georeference |
| GeoJSON | FeatureCollection with attributes | QGIS, web GIS; needs a georeference |
| Shapefile (zip) | One shapefile per layer and geometry type (Z where an elevation counts), UTF-8 attributes with diameters, flows, velocities and pressures, a `.prj` | GIS; UTM on SIRGAS 2000 / WGS 84 when georeferenced, local metres otherwise |
| GPX | Every point item as a waypoint (lateral outlets one by one) and the linear items as tracks | Staking out with a GPS; needs a georeference |
| LandXML 1.2 | The terrain TIN and its source data, the point items as CgPoints, one pipe network per zone and for the mainline with inverts, diameters and design flows | Survey and civil software |
| IFC 4 | Site with the terrain, pipes as swept solids at their burial depth, terminals, valves, filters, meters, pumps and tanks with property sets and hydraulic values, one distribution system per zone | BIM; Reference View |
| EPANET (.inp) | The network of a system flow (or of everything open), with pumps, valves, emitters and the valve-in-head heads that flow runs | EPANET 2.2; Hazen-Williams, Darcy-Weisbach or Chezy-Manning |
| CSV, TXT, XLSX, PDF | Reports (all tables) | XLSX with one sheet per table and numbers as numbers |
| Controller CSV | Irrigation programme: events per system flow, days and times | File → Export report, or the System flows dialog |
