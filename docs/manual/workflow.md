# Design workflow

The workflow follows established irrigation design practice (inventory and terrain, layout, zones,
management, mainline, materials and plotting), adapted to a browser app.

1. **Project details** (File → Project details…): name, client, site, designer and notes, which go
   to the sheet title block and the reports. Units (metric or US) in Tools → Units.
2. **Background information**: import the base (DXF, DWG, DGN, a PDF plan, KML/KMZ, SHP, GeoJSON,
   GPX, survey CSV, GeoTIFF, satellite image), draw boundaries, buildings and roads, or walk them
   with the device GPS (Draw → GPS in the field). Images and plans out of scale are fitted with
   Align by 2 points (AL). Georeference the project (File → Georeference…) when you want base maps,
   online elevation and climate or KML/GeoJSON/GPX export. Design → Automatic design → Detect
   vegetation in the image… turns the lawns and tree crowns of an aerial view into irrigated areas.
3. **Terrain**: draw contour lines (CT), breaklines (BRK) and spot heights (SP), import a survey,
   a LAS point cloud, a LandXML surface or an elevation GeoTIFF, or download the elevation from the
   internet for a coordinate. Generate contours from the model and check them in 3D or on the slope
   map.
4. **Hydraulic layout**: water supply (WS), pump (PU), mainline (MP), zone valves (V) and, downstream
   of each valve, zone pipes (ZP), laterals (SL), tapes (DT), emitters (OUT), devices (F). The
   **lateral block** (B) and **sprinkler grid** (AH) generators and the **automatic design** tools
   (Design → Automatic design) do the repetitive work: heads laid out, zoned and piped, fields cut
   into blocks, drip rings, turf templates, pivots fitted to a field. Irrigated areas (AR) carry
   crop, soil, efficiency and water balance; Design → Site climate… gives them the monthly climate.
5. **Management** (Design → System flows): system flows (which valves, pivots and valve-in-head
   stations open together, start time and duration). Without defined flows, all valves are assumed
   to open together (the worst case for the mainline and the supply). *Automatic…* groups the zones
   into the fewest flows that fit the supply flow (or a flow and a number of zones you choose),
   largest demands first; Design → Group zones for energy… groups zones of similar head, and
   Time-of-use tariff and flow schedule… chooses the start hours of least energy cost.
   **Wiring**: a controller (CTRL) and the wire routes (WR) to the valves, drawn by hand or along
   the pipe trenches (Zone → Automatic wire routes…), sized in the design.
6. **Check** (Design → Design check…): unconnected items, pipes crossing without a junction, dead
   ends, zones without emitters or mixing emitter kinds, missing catalogue items, missing terrain.
7. **Design** (F5): zones, mainline, telescoping, flushing, water hammer, mechanised machines and
   materials. You can also design only the zones, only the mainline, or just analyse with the
   current diameters (also automatically after every edit). The Mainline menu then checks the
   mainline further: hydraulic transients, air valves, a 24-hour simulation, on-demand operation,
   pipe criticality, roughness calibration and fertigation.
8. **Reports and plotting**: reports panel, PDF sheets (one sheet, or an overview and a sheet per
   zone or area) with title block, legend, north arrow, scale bar, bill of materials, construction
   details and charts; a commercial quote; exports to other CADs, GIS, BIM, EPANET and spreadsheets.
