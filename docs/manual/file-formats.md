# File formats

## Project (`.oci.json`)

Readable JSON with these top-level keys:

| Key | Contents |
|---|---|
| `format`, `version` | `"opencadirrigation"`, `2` (files of version 1 are upgraded as they are read; the old name `irrigationcad` is still accepted) |
| `meta` | Stable uid, creation and modification dates, name, client, site, designer, notes, georeference (UTM zone, hemisphere, E/N origin, and the datum when one is chosen), the professional title block (`titleBlock`, only when something is set; the logo travels in the file, not in share links) |
| `params` | All design parameters and the units |
| `catalog` | The whole project catalogue (the file is self-contained) |
| `layers` | Name, ARGB colour, visible, locked |
| `entities` | One entry per entity, with `type`, `id`, `layer`, `name` and its own fields (points in metres; a pivot keeps its machine data under `mach`; an irrigated area keeps the direction of its planting rows read by Crop rows from the image under `rdir`, in degrees counter-clockwise from east within [0, 180), beside its row and plant spacings `rsp` and `psp`, written only when set and turned and mirrored with the area) |
| `systemFlows` | System flows: name, valves (and pivots and valve-in-head stations), start time, duration |
| `proposal`, `scenarios`, `climate`, `labelRules`, `blocks`, `aiNotes` | Optional: quote settings, design alternatives, site climate (with the daily series of a station file or a download), conditional labels, user blocks, the AI assistant's notes about the project |
| `agronomy`, `agb`, `deliverables`, `dimStyle`, `layerStates` | Optional, written only when they differ from a new project: the agronomy plan (user crops, programme, water balance, fertigation by stage, field tests), the settings of power, water and machines, those of the technical documents, the dimension style and the named layer states |
| `climateRisk` | Optional: the summary of the last Climate risk over the years (the source of the series and its credit, the site, the first and last year, the day it was computed, the probability and the peak period chosen, a few figures per site year and per area and season, and the figures the design used), never the daily series; a damaged summary is dropped as it is read |
| `unreadable` | Items this version could not read (damaged, or of a newer version), kept and written back so that a later version gets them |
| `nextId`, `currentLayer` | Id counter and current layer |
| `results` | Optional: results of the last calculation, to reopen with reports without recalculating |

The same JSON is used by the autosave, the versions, the cross-project clipboard, share links and
the calculation worker. The file opens item by item: an item that cannot be read is set aside (under
`unreadable`), vertices without coordinates are dropped, an unknown elevation is never taken as 0 m,
repeated or missing ids are renumbered, options it does not know take their default and fields of a
newer version are kept; the app then says what it repaired. `oci schema` prints the JSON Schema of the
file, built from the model. File → Insert project… merges another project file into the open one,
with new ids (the references between its items kept), the catalogue items it uses (renamed when the
open project has another item under the same id, priced in its currency), the layers it lacks, the
system flows that run its items and its blocks; with both georeferences the items land in the same
place on the ground, an empty project without one takes that of the file, otherwise they come in as
drawn. The block library exports as a `.oci-blocks.json` file.

## Import

| Format | What comes in | Details |
|---|---|---|
| DXF (ASCII) | LINE, LWPOLYLINE and POLYLINE (with bulge arcs), CIRCLE, ARC, ELLIPSE, SPLINE (through its fit points, or the NURBS curve of its control points, knots and weights), HATCH (boundary paths of polylines, lines, arcs, ellipses and splines; pattern angle and spacing; islands as polylines), SOLID, TRACE, TEXT, MTEXT (with its paragraphs), ATTRIB, LEADER (its line), MULTILEADER, MLINE, POINT, 3DFACE and meshes, layers and blocks (INSERT, MINSERT and the block of every DIMENSION, nested too) | R12 to 2018, read group by group in slices with progress and Cancel; the code page of `$DWGCODEPAGE` (single-byte tables and the Japanese, Chinese and Korean pages 932, 936, 949 and 950), Latin-1 or UTF-8; `\U+XXXX` characters, `%%c`/`%%d`/`%%p` symbols and MTEXT codes decoded; polylines with elevation (2D or 3D vertices) become contour lines and breakline layers breaklines; points with Z, 3D faces, meshes and survey blocks (an INSERT whose ATTRIB holds the elevation, with a decimal comma or a unit, or the elevation of the insertion) become spot heights; the hydraulic XDATA of a drawing this app exported brings its pipes and items back as a network; scale from the file units; layers that are off or frozen come in hidden; paper space is left out, and the entity types without support are named in the warning; block expansion is capped against cycles and explosive blocks, and a missing external reference is reported |
| DWG | Same entities (ELLIPSE, SPLINE, HATCH, SOLID, TRACE, LEADER, ATTRIB, 3DFACE and MLINE included; 2D polylines with their arcs), layers with their colours, blocks (INSERT, MINSERT), dimensions and the hydraulic XDATA; like the DXF, entities mirrored in the CAD program (extrusion 0, 0, −1) land where the CAD shows them | R13/R14 (partial), 2000, 2004, 2007, 2010, 2013 and 2018, in pure Dart, read in slices with progress and Cancel; units from `$INSUNITS`, the code page of the header (CJK included); handle maps read whichever way the writer coded them; skipped objects reported, the classes left out (MULTILEADER, IMAGE, WIPEOUT…) named |
| DGN V7 | Lines, line strings, shapes, curves, complex chains and shapes, circles, ellipses, arcs, texts, cells; levels as layers (`LEVEL_<n>`); 2D and 3D files (a constant Z becomes the elevation) | Units from the master/sub-unit ratio and the global origin of the file; DGN V8 is refused by name |
| PDF (plan) | A page as an underlay: lines, polylines and outlines, texts with their height and angle, images, PDF layers (layers off by default only on request), one layer per import and optionally per colour | File → Import opens a dialog: page with a preview, scale 1:N (read from the sheet when written there, or chosen, or metres per PDF unit), insertion point, contents; then Align by 2 points. Encrypted files are refused; JPEG 2000 and JBIG2 images are skipped; filled areas come as outlines |
| KML / KMZ | Placemarks, folders as layers, GPS tracks (gx:Track), altitude or ELEV attribute as elevation; the image overlays of a KMZ (GroundOverlay with a LatLonBox and rotation, or a rectangular gx:LatLonQuad) as a georeferenced background, with the transparency of their colour and their drawing order | WGS84 → UTM (automatic zone) with a local origin; georeferences the project; an overlay whose picture comes from the internet or cannot be read is named in the warning |
| SHP (+ DBF, PRJ, CPG in a zip) | Points, lines, polygons, multipoints, Z variants; a zip with several shapefiles brings each on the layer of its name | Read record by record with progress and Cancel; elevation from Z or from an ELEV/Z/COTA attribute; name from NAME/NOME/ID; attributes in the code page of the `.cpg` (UTF-8, Latin-1, the Windows pages and the CJK ones); the `.prj` places the data (below); without one, degrees are recognised by range and precision |
| GeoJSON | FeatureCollection, Feature, GeometryCollection or a bare geometry, every geometry type; name, elevation and layer from the properties | RFC 7946 longitude/latitude on WGS 84, or the `crs` member of the 2008 specification (UTM on SIRGAS 2000, SAD 69 or Córrego Alegre lands in place); points without height become markers |
| GPX | Waypoints (with elevation: spot heights), routes and tracks | GPX 1.1 and 1.0 |
| LandXML | CgPoints, surfaces (the TIN, or contours, breaklines, points and boundaries) and pipe networks | Decimated to the terrain limit; CRS from the file; imperial units converted |
| LAS | The ground points (class 2) of a point cloud as terrain, thinned on a grid while reading | LAS 1.0–1.4, point formats 0–10, CRS from the GeoTIFF keys or the WKT; compressed LAZ is refused |
| EPANET (.inp) | The network drawn: pipes, pumps and valves as polylines on `EPANET_*` layers, nodes with their ids | US units converted; placed by the georeference or in local metres; the engine reader also builds the hydraulic network ([docs/API.md](../../docs/API.md)) |
| CSV, TXT, XYZ, PTS, PNEZD | Survey points | File → Import opens the points wizard: the first lines as a table, the role of each column (point, easting, northing, elevation, latitude, longitude, description, ignore), the separator, the decimal mark, a header, lines to skip, the encoding and the coordinate system (local metres, the project's UTM, latitude and longitude, the UTM of a zone on a datum, an EPSG code), with a world map showing where the points land (and, as a ring, where they would with latitude and longitude swapped) and a warning when they fall far from the project; columns detected by header or position, PENZ or PNEZ by the size of the UTM values, decimal comma and thousands separators accepted; points without an elevation become markers |
| Elevation GeoTIFF | Elevation grid | One band of heights, float or integer, nodata ignored; classic TIFF, BigTIFF and cloud-optimised GeoTIFF read block by block (uncompressed, LZW, Deflate, PackBits, JPEG; predictors 2 and 3; the empty blocks of sparse files) and sampled on the grid of the model without decoding the rest |
| JPG, PNG, GeoTIFF, zip with world file | Background image | Georeferenced (world file, rotated too; GeoTIFF tags, with a projection given key by key) or placed by hand and aligned by 2 points; large TIFF rasters (drone orthomosaics of hundreds of megapixels, BigTIFF, cloud-optimised GeoTIFF with its reduced overviews, up to 4 billion pixels) are reduced by averaging as they are read, with only the rows in progress in memory; JPG, PNG and other pictures over 100 million pixels are refused before decoding |

**Coordinate systems.** The readers that carry a CRS (shapefile `.prj`, GeoJSON `crs`, LandXML,
LAS, GeoTIFF) recognise WKT 1 (ESRI and OGC flavours), WKT 2, EPSG codes and OGC URNs, with the
transverse Mercator (UTM) and the Albers equal-area, Lambert conformal conic and polyconic projections
(Snyder 1987), including the national grids of EPSG 5880 and 29101 (Brazil Polyconic), 10857 (Brazil
Albers), 2154 (Lambert-93), 3034 (LCC Europe), 5070 (Conus Albers) and 6372 (Mexico LCC); RGF93 is
read as ETRS89. SAD 69 and Córrego Alegre data are shifted to SIRGAS 2000 with the IBGE
three-parameter translations (accurate to a few metres); SIRGAS 2000, WGS 84, ETRS89 and NAD83 are
treated as identical at the accuracy of a project map. An unrecognised system is reported, not
guessed. A drawing in UTM of the project's zone comes in shifted by the origin of the georeference,
in place on the satellite map.

**Large files** are read in slices before the import changes the project, with a progress and
Cancel (*Import cancelled: the project did not change*): DXF, DWG and LAS by their own readers,
GeoTIFF block by block, shapefiles record by record and KML/KMZ between pauses; small files skip the
dialog. Compressed files (KMZ, XLSX, zipped shapefiles and pictures, share links) are opened entry by
entry up to a ceiling each, against zip bombs. A share link of a large project asks before it
opens.

## Catalogues and examples

`.oci.cat` packs in [catalogs/](../../catalogs/) (format in [catalogs/README.md](../../catalogs/README.md)) and
example projects in [examples/](../../examples/), regenerated by tools and guarded by tests.
