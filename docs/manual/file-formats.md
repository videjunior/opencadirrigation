# File formats

## Project (`.oci.json`)

Readable JSON with these top-level keys:

| Key | Contents |
|---|---|
| `format`, `version` | `"opencadirrigation"`, `1` (the old name `irrigationcad` is still accepted) |
| `meta` | Stable uid, creation and modification dates, name, client, site, designer, notes, georeference (UTM zone, hemisphere, E/N origin) |
| `params` | All design parameters and the units |
| `catalog` | The whole project catalogue (the file is self-contained) |
| `layers` | Name, ARGB colour, visible, locked |
| `entities` | One entry per entity, with `type`, `id`, `layer`, `name` and its own fields (points in metres; a pivot keeps its machine data under `mach`) |
| `systemFlows` | System flows: name, valves (and pivots and valve-in-head stations), start time, duration |
| `proposal`, `scenarios`, `climate`, `labelRules`, `blocks`, `aiNotes` | Optional: quote settings, design alternatives, site climate, conditional labels, user blocks, the AI assistant's notes about the project |
| `nextId`, `currentLayer` | Id counter and current layer |
| `results` | Optional: results of the last calculation, to reopen with reports without recalculating |

The same JSON is used by the autosave, the versions, the cross-project clipboard, share links and
the calculation worker.

## Import

| Format | What comes in | Details |
|---|---|---|
| DXF (ASCII) | LINE, LWPOLYLINE and POLYLINE (with bulge arcs), CIRCLE, ARC, ELLIPSE, SPLINE (through its fit points, or the NURBS curve of its control points, knots and weights), HATCH (boundary paths of polylines, lines, arcs, ellipses and splines; pattern angle and spacing; islands as polylines), SOLID, TRACE, TEXT, MTEXT, ATTRIB, LEADER (its line), POINT, layers and blocks (INSERT, MINSERT and the block of every DIMENSION, nested too) | R12 to 2018, Latin-1 or UTF-8; `\U+XXXX` characters, `%%c`/`%%d`/`%%p` symbols and MTEXT codes decoded; polylines with elevation (2D or 3D vertices) become contour lines and breakline layers breaklines; points with Z become spot heights; scale from the file units |
| DWG | Same entities (ELLIPSE, SPLINE, HATCH, SOLID, TRACE and LEADER included; 2D polylines with their arcs), layers, blocks (INSERT, MINSERT) and dimensions; like the DXF, entities mirrored in the CAD program (extrusion 0, 0, −1) land where the CAD shows them | R13/R14 (partial), 2000, 2004, 2007, 2010, 2013 and 2018, in pure Dart; handle maps read whichever way the writer coded them; reports skipped objects |
| DGN V7 | Lines, line strings, shapes, curves, complex chains and shapes, circles, ellipses, arcs, texts, cells; levels as layers (`LEVEL_<n>`); 2D and 3D files (a constant Z becomes the elevation) | Units from the master/sub-unit ratio and the global origin of the file; DGN V8 is refused by name |
| PDF (plan) | A page as an underlay: lines, polylines and outlines, texts with their height and angle, images, PDF layers (layers off by default only on request), one layer per import and optionally per colour | File → Import opens a dialog: page with a preview, scale 1:N (read from the sheet when written there, or chosen, or metres per PDF unit), insertion point, contents; then Align by 2 points. Encrypted files are refused; JPEG 2000 and JBIG2 images are skipped; filled areas come as outlines |
| KML / KMZ | Placemarks, folders as layers, GPS tracks (gx:Track), altitude or ELEV attribute as elevation | WGS84 → UTM (automatic zone) with a local origin; georeferences the project |
| SHP (+ DBF, PRJ, CPG in a zip) | Points, lines, polygons, multipoints, Z variants; a zip with several shapefiles brings each on the layer of its name | Elevation from Z or from an ELEV/Z/COTA attribute; name from NAME/NOME/ID; attributes in UTF-8 or Latin-1 (.cpg); the `.prj` places the data (below); without one, degrees are recognised by range and precision |
| GeoJSON | FeatureCollection, Feature, GeometryCollection or a bare geometry, every geometry type; name, elevation and layer from the properties | RFC 7946 longitude/latitude on WGS 84, or the `crs` member of the 2008 specification (UTM on SIRGAS 2000, SAD 69 or Córrego Alegre lands in place); points without height become markers |
| GPX | Waypoints (with elevation: spot heights), routes and tracks | GPX 1.1 and 1.0 |
| LandXML | CgPoints, surfaces (the TIN, or contours, breaklines, points and boundaries) and pipe networks | Decimated to the terrain limit; CRS from the file; imperial units converted |
| LAS | The ground points (class 2) of a point cloud as terrain, thinned on a grid while reading | LAS 1.0–1.4, point formats 0–10, CRS from the GeoTIFF keys or the WKT; compressed LAZ is refused |
| EPANET (.inp) | The network drawn: pipes, pumps and valves as polylines on `EPANET_*` layers, nodes with their ids | US units converted; placed by the georeference or in local metres; the engine reader also builds the hydraulic network ([docs/API.md](../../docs/API.md)) |
| CSV, TXT, XYZ, PNEZD | Survey points | Columns detected by header or position; decimal comma accepted (also in columns separated by spaces), thousands separators too; a text column names the points; lat/lon recognised |
| Elevation GeoTIFF | Elevation grid | One band of heights, float or integer, nodata ignored; BigTIFF is refused by name |
| JPG, PNG, GeoTIFF, zip with world file | Background image | Georeferenced (world file, rotated too; GeoTIFF tags) or placed by hand and aligned by 2 points; rasters over 100 million pixels are refused before decoding |

**Coordinate systems.** The readers that carry a CRS (shapefile `.prj`, GeoJSON `crs`, LandXML,
LAS) recognise WKT 1 (ESRI and OGC flavours), WKT 2, EPSG codes and OGC URNs. SAD 69 and Córrego
Alegre data are shifted to SIRGAS 2000 with the IBGE three-parameter translations (accurate to a
few metres); SIRGAS 2000, WGS 84, ETRS89 and NAD83 are treated as identical at the accuracy of a
project map. An unrecognised system is reported, not guessed.

## Catalogues and examples

`.oci.cat` packs in [catalogs/](../../catalogs/) (format in [catalogs/README.md](../../catalogs/README.md)) and
example projects in [examples/](../../examples/), regenerated by tools and guarded by tests.
