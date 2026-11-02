# Terrain

- **Elevation sources**: drawn contour lines (with automatic increment and optional smoothing),
  breaklines (`BRK`: ridges, channels and banks the surface must fold along), spot heights (the
  elevation is asked at every click), survey points (CSV, TXT, XYZ, PTS, PNEZD, through the import
  wizard), DXF/DWG/DGN with elevation (polylines on contour layers or with an elevation; in DXF and
  DWG also 3D faces, meshes and survey blocks whose attribute or insertion carries the elevation), KML
  with altitude,
  shapefile with Z or an elevation attribute, GPX waypoints, LAS point clouds (the ground class),
  LandXML surfaces and points, elevation GeoTIFF (single-band raster, BigTIFF and cloud-optimised
  GeoTIFF included, sampled on the grid without decoding the rest) and **online elevation**.
- **Digital terrain model**: Delaunay triangulation (TIN) constrained by the breaklines, with linear
  interpolation inside the triangles, exact on planar slopes, and inverse-distance interpolation as
  an alternative and as a complement outside the convex hull (with the exact nearest samples, near
  or far from the data). Contour lines are sampled every 5 m (adjustable). The TIN takes up to 40 000
  samples as they are; above that it keeps every sample of your own survey (contours, spot heights,
  breaklines, points) and an even spread of the downloaded elevation model, with the corners of its
  outline, which the app says once per project (the IDW interpolation uses all of them); point clouds
  and LandXML surfaces are thinned on a grid as they are read. The model does not depend on the order
  of the items: the samples are numbered by their position before the triangulation, so co-circular
  points (the cell of a grid) always get the same diagonal, and samples at the same place (within
  1 mm) merge, a breakline vertex winning over the other points and points of one kind taking the
  mean of their elevations. An elevation that is not known is never taken as 0 m, and hydraulic items
  more than 10 m outside the terrain data are warned about (`outside_terrain`: their elevation is
  extrapolated).
- **Online elevation** (Design → Terrain → Download elevation from the internet (DEM)…): a grid of
  points over the project or over the visible area is queried from free public services with no
  key: Terrain Tiles on AWS Open Data (SRTM 30 m, GMTED, ETOPO1; the default), Open-Meteo
  (Copernicus GLO-90; 600 coordinates per minute) and, in the desktop builds, OpenTopoData (SRTM
  30 m, ASTER 30 m; its public API sends no CORS header, so browsers cannot use it). The download
  replaces the heights you entered by default, since they are usually on another datum than the
  model. In an empty project you can just paste the coordinate of the site (decimal, Google Maps
  link or degrees/minutes/seconds): the drawing origin moves there and the elevation is downloaded
  in a square around it. When it finishes, contour lines can be generated automatically with an
  interval chosen from the relief. The tiles and points downloaded are kept on the device (File →
  Saved downloaded data…), so making the terrain again does not download them again and works with a
  poor connection in the field.
- **Tools**: generate contour lines from the model (derived curves that do not feed the model back),
  3D view of the terrain with the pipes draped on it, slope and aspect maps (View → overlay, with
  the share of the area in each slope class), profile along a path (with the pipe and the
  hydraulic grade line when there are results); the pressure of every emitter accounts for the
  ground elevation plus the riser height minus the burial depth.
