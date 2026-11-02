# Title block and technical documents

What a professional delivers with a design besides the drawings: the title block with the technical lead, the datum
of the coordinates, the documents a water agency, a client, an installer or an operator asks for, and the standards
behind each figure. The app is a design aid: a qualified professional checks and signs what it produces.

## Title block and technical lead

File → *Title block and technical lead…* (also in the phone menu) fills the title block of every sheet and the cover
of the document packages: the project (property, municipality/state), the records (CAR, the rural environmental
registry; the water permit number; the stage, from feasibility study to as built), the technical responsibility
(technical lead, professional body such as CREA or CAU, registration number and the ART, RRT or TRT record), the
sheets (drawing number, date of issue, revisions with their author) and the company with its logo (PNG or JPEG,
scaled down to 512 px; kept in the project file, left out of share links). OK is one undo step and Cancel puts
everything back; *Save as my defaults* keeps the company, logo, technical lead, council and registration in this
browser, and *Fill in my defaults* fills them in on another project.

Once any of these fields is filled in, the sheets carry the **professional title block**, 40 mm tall instead of 30 mm
(the drawing area is 10 mm shorter): cells laid out as the data fields of ISO 7200, with the project, the records,
the technical responsibility, the sheet (drawing number and sheet, scale and paper, date, the coordinate system with
its EPSG code and origin) and a column for the company and its logo. The revision table of the sheets joins the
revisions of the title block and those of the revision clouds. With nothing filled in, the sheets keep the title
block of earlier versions.

## Datum of the coordinates

File → Georeference… has a *Datum of the coordinates*: automatic by the site (SIRGAS 2000 in South and Central
America, ETRS89 in Europe, WGS84 elsewhere) or SIRGAS 2000, WGS84, ETRS89 or NAD83 chosen. These datums agree at the
accuracy of a project map (under 1 m), so the choice changes no coordinate: it names them on the sheets and in the
shapefile `.prj`, LandXML, IFC and EPANET files. Earlier versions named SIRGAS 2000 in those files wherever the
project was; old files keep their coordinates.

## Coordinate grid and terrain sheets

The PDF plot options add:

- a **coordinate grid** over the drawing: UTM (E, N) of the project's zone, local (X, Y) without a georeference,
  geographic (latitude and longitude in degrees, minutes and seconds) or UTM and geographic, with the values along
  the edges of the drawing area, clear of the north arrow and the scale bar;
- extra **slope** and **aspect** sheets: the slope map by class, or the aspect by compass sector, under the drawing
  in grey, with the key, the area of each class and, for the slope, the classes of each irrigated area. They need
  contour lines or spot heights.

The report *Slope by irrigated area* (in the Water requirements tab, and needing no design) gives the area of each
slope class in every irrigated area, with its mean and largest slope.

## Document packages

File → *Export document package (PDF)…* writes one PDF for each reader instead of every table at once:

| Package | For |
|---|---|
| Technical and commercial proposal | The client: the system in brief, the scope (bill of materials), the quote and its terms, the works schedule, the plan and the client's acceptance |
| Water permit and licensing | The water agency and the licensing: identification, the abstraction points in UTM and in degrees, minutes and seconds, the water requirement, the crops, the licensing category, the slope and the georeferenced plans with the coordinate grid and the slope map |
| Installation package | The works: the sheets by zone with the construction details, the pressures to check and the materials by zone |
| Technical report | The technical file and tenders: criteria and standards, the hydraulic design, the checks and every sheet |
| Operation and maintenance | Whoever runs the system: the management by crop, the pressures of each zone and the flushing of the lines |

Every package has a cover with the data of the title block (logo, company, client, property, technical lead and
records), a table of contents with page numbers, numbered sections with a running header, the drawings on their own
paper and the signature block of the technical lead. The dialog chooses the package, the title on the cover, the
recipient, the paper of the drawings and the base map, and the sections, its own and those of the other packages; a
section that needs the design results or data the project lacks says so.

## Technical documents

Reports → *Technical documents* opens five documents built from the project in pure Dart, each a dialog whose
settings are one undo step (Cancel puts them back) and which exports PDF, XLSX, CSV or Markdown (to edit the text);
they also enter the document packages.

- **Water permit table and self-monitoring**: for every water source, what a permit application asks for the point of
  abstraction (coordinates on SIRGAS 2000 in degrees, minutes and seconds and in UTM with the EPSG code, the water
  body, the purpose, the irrigated area and its crops, the pumps) and the regime of every month from the gross
  requirement of the areas (flow, hours a day, days a month, volume a day and a month), with the check of the
  capacity, the floor of 300 m³/ha a month of Resolution ANA 1,939/2017, the self-monitoring of Resolution ANA
  188/2024 and the sheet of monthly readings. Sources: Law 9,433/1997, those two resolutions and IBGE R.PR 1/2005;
  rivers and aquifers under state control follow the rules of the state agency.
- **Descriptive and calculation memorial**: written from the project alone, without the AI assistant (the same
  project gives the same text): identification, objective, areas and crops, climate and water requirement, water
  source, design criteria, the formulas the program uses with their symbols and sources, the zones, the network,
  pumping and energy, operation, the checks, the materials, your remarks and the references. You write the objective
  and the closing remarks.
- **Operation and maintenance plan**: the hand-over manual with the figures of the design: start-up (filling,
  flushing, the pressure test at 1.5 times the working pressure within the class of the pipes, the first run of every
  zone), the sheet of the pressures of every zone, the flushing of the laterals, the cleaning of the filters by the
  rise of their loss, chlorination at the injection rate of every system flow, the off-season, the schedule by
  component, the self-monitoring and the spare parts.
- **Budget by unit-cost compositions**: the services of the construction schedule, each with the composition of the
  labour and equipment a unit takes (the productivities of the schedule at hourly costs), the materials of the bill
  at the catalogue prices, the BDI of the services and the BDI of the supply of materials (checked against the
  reference ranges of TCU Ruling 2622/2013), the taxes on the price and the physical-financial schedule by week or
  month. The starting hourly costs are examples: replace them with those of the reference cost table of your region
  and date (SINAPI in Brazil).
- **Life-cycle cost**: the current design and every alternative saved with its results compared by investment,
  replacements, residual value, energy, water and maintenance over a horizon, brought to present value, LCC = I +
  Repl − Res + E + W + OM&R (NIST Handbook 135), with the discount rate (or the interest of the design parameters),
  the real rise of the energy price, the water price and the life and maintenance of every category of parts
  (reference values to adjust to the manufacturers' data and local experience).

## Standards in the reports

Every report table names, under its title, the criteria it shows and the standards or references each follows (ABNT
NBR, ISO, EN, ASABE/ASAE, AWWA, IEC, FAO, NRCS, CONAMA), in the PDF, CSV and TXT exports, so the reader of a memorial
or of a permit application sees where every limit comes from. The design check adds `supply_no_meter` (information):
a water source with no flow meter on its line and no hour meter on its pumps, which the self-monitoring of a permit
needs.
