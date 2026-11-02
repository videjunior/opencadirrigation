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
electrical, valve-in-head stations, power, water and machines
([Power, water and machines](power-water-machines.md)) and *Irrigation management* with the daily water
balance, the runoff potential, the capacity against the peak, the programme by station, fertigation
by stage and the field evaluations ([Agronomy and irrigation scheduling](agronomy.md)). The mainline
tab also holds the pump stations (the duty of every pump in every system flow) and the real operation
of the zones; the water requirements tab holds *Slope by irrigated area*, and the crop requirement
tab the *Data sources and credits*. Under its title every table names the criteria it shows and the standards they follow
([Title block and technical documents](technical-documents.md#standards-in-the-reports)).

Tables are virtualised, with columns measured from their content, and are the basis of every
exporter, so PDF, Excel and CSV show the same numbers. A click on a header sorts the table (again
reverses it, a third time gives back the order of the report), a filter keeps the rows with a text or
only the highlighted ones, the visible rows copy to the clipboard (to paste into a spreadsheet) and
the tab saves as CSV; a row of zones, pipes, emitters, comments or revisions selects and frames its
item on the drawing. Export report works without a design for the tables that do not need one (water,
crop, comments, revisions, requirements…).

## PDF sheets

File → Export drawing → PDF opens the plot options: size (A4 to A0, Letter, Tabloid, the elongated
sheets of ISO 5457 from A3×3 to A0×2, ANSI C, D and E, or a custom size from 100 to 5000 mm a side for
plotter rolls), orientation, scale (automatic or fixed; "1.500" typed is 1500), margin, wetted radii,
labels, layer legend, bill of materials on the
sheet, the base map of the screen under the drawing (with its credit, and below it those of the
base map pictures kept for the field and of the online elevation shown) and attached report pages.
A PDF can hold a **set of sheets**: one sheet, or an overview plus one sheet per zone or per
irrigated area (each fitted to its subject with its own materials, the other zones in grey or
hidden), and the current screen view as an extra sheet at its own scale; then **construction
details** (trench, thrust block, valve box, sprinkler riser and swing joint, drip line connection,
air valve, filter station, pump suction) drawn with the design's own pipes, depths, models and
pressures; and **charts** (the mainline grade line of every system flow, the terrain profile and
the pump curves with their duty points). Revision clouds and open comments print on the sheets, and
the revision table lists them under the legend. The scene is built in "paper space": pens, symbols
and texts in paper millimetres, so that 1:500 and 1:2000 are equally legible. The title block
carries the project details, the north arrow and the scale bar; with the fields of File → Title block
and technical lead… it becomes the professional title block, and the options add a UTM or geographic
coordinate grid and extra slope and aspect sheets
([Title block and technical documents](technical-documents.md)). The dialog shows a **preview** of
every sheet of the set, made again after each option. Two more options: **layers in the PDF**, one
per layer of the project and one for the base map, switched on and off in the viewer, and
**PDF/A-2b** for archiving (public bodies), a PDF 1.7 with its identifier, the XMP of its
information, an sRGB output intent and every font embedded (the Helvetica text drawn with Noto Sans at
Helvetica's widths; without the font the file does not call itself PDF/A).

The PDF writer is our own (PDF 1.4, Flate compression), with no native dependencies: the text
Helvetica can show stays in Helvetica, and any other script (Cyrillic, Greek, Vietnamese, Arabic,
Urdu, Hindi, Marathi, Bengali, Punjabi, Telugu, Chinese, Japanese) is set with embedded subsets of
the bundled Noto fonts, shaped and ordered (bidirectional text) by the app itself, so copy and
search give the text back. Images are embedded (JPEG passed through, other images with their
transparency) and downsampled for the size they are printed at. The same sheet exports as **PNG**
(File → Export drawing → PNG, 96 to 300 dpi, about 40 megapixels at most).

## Commercial quote and alternatives

Design → Commercial quote… turns the bill of materials into a quote: sale prices with the margin,
labour, trench excavation (volumes from the buried pipes and the trench settings, with the default
depth of the mainline pipes, 0.6 m, and of the zone pipes, 0 = on the surface, for those without
their own, which the automatic tools use too), extra lines,
discount, taxes and freight, validity and terms; payback, net present value and internal rate of
return from a yearly benefit; a construction schedule from the crews and their output per day; the
FINAME codes (financing by the Brazilian development bank BNDES) of the items that have one. Design
→ Design alternatives… keeps named copies of the project with their key figures, compares them side
by side and restores one in one undo step.

## Exports

| Format | Contents | Notes |
|---|---|---|
| DXF | R2000 (AC1015) with native entities: polylines with arcs, splines, hatches, dimensions, leaders, multiline text; symbols and hydraulic items as blocks with attributes (NAME, ITEM, NOZZLE, ZONE, STATIONS); layers with true colours and dashed linetypes; user blocks as block definitions and block references as INSERT with ATTRIB; the islands of the areas as hatches; the hydraulic data of every pipe, lateral, tape and hydraulic item as extended data (XDATA of the registered application OPENCADIRRIGATION: kind, catalogue item, diameters, length and, with results, flows, velocity, head loss and pressures) | Validated with ezdxf and LibreDWG and re-read by the app's reader, which brings the network back from the XDATA; other readers see the whole drawing |
| DXF R12 | The plain primitives of the earlier export, one text per line | For older programs |
| DWG | R2000 (AC1015), the same native drawing (colour indices only) with the same XDATA | Our own writer, validated with LibreDWG and re-read by the app's reader |
| PDF | Sheet sets with title block, legend, north arrow, scale bar, details, charts and, optionally, reports, the coordinate grid, slope and aspect sheets, layers and PDF/A-2b | Every interface script |
| Document package (PDF) | File → Export document package: a proposal, a water permit and licensing file, an installation package, a technical report or an operation and maintenance file, with cover, contents, numbered sections, drawings and signature | [Title block and technical documents](technical-documents.md#document-packages) |
| PNG | The sheet as an image, 96–300 dpi | |
| SVG | Sheet in millimetres, one group per layer, images embedded | Browsers, Inkscape |
| KML / KMZ | Folders per layer, WGS84 coordinates | Google Earth; needs a georeference |
| GeoJSON | FeatureCollection with attributes | QGIS, web GIS; needs a georeference |
| Shapefile (zip) | One shapefile per layer and geometry type (Z where an elevation counts), UTF-8 attributes with diameters, flows, velocities and pressures, a `.prj`, the islands of the areas as inner rings | GIS; UTM on the datum of the georeference (SIRGAS 2000, ETRS89, WGS84 or NAD83; by default the one of the site) when georeferenced, local metres otherwise |
| GPX | Every point item as a waypoint (lateral outlets one by one) and the linear items as tracks | Staking out with a GPS; needs a georeference |
| Stake-out points (CSV) | File → Export drawing → Stake-out points (PNEZD): number, UTM coordinates of the project (local ones without a georeference), terrain elevation and description of the emitters and sprinklers, valves, pumps, supplies and devices, pipe vertices and the ends of the laterals, as P,N,E,Z,D or P,E,N,Z,D, with the first number and the decimals chosen | The list a total station or a GNSS RTK receiver loads directly |
| LandXML 1.2 | The terrain TIN and its source data, the point items as CgPoints, one pipe network per zone and for the mainline with inverts, diameters and design flows | Survey and civil software |
| IFC 4 | Site with the terrain, pipes as swept solids at their burial depth, terminals, valves, filters, meters, pumps and tanks with property sets and hydraulic values, one distribution system per zone | BIM; Reference View |
| EPANET (.inp) | The network of a system flow (or of everything open), with pumps, valves, emitters and the valve-in-head heads that flow runs | EPANET 2.2; Hazen-Williams, Darcy-Weisbach or Chezy-Manning |
| CSV, TXT, XLSX, PDF | Reports (all tables), with the standards of each table in the PDF, CSV and TXT | XLSX with one sheet per table and numbers as numbers |
| PDF, XLSX, CSV, Markdown | The technical documents of Reports → Technical documents (water permit table, memorial, operation and maintenance plan, budget by compositions, life-cycle cost) | Markdown to edit the text |
| Controller CSV | Irrigation programme: events per system flow, days and times | File → Export report, or the System flows dialog |
