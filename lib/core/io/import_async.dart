/// The heavy readers of an import run in slices ([WorkSlicer]) before the
/// import changes the project: GeoTIFF block by block (elevation models
/// sampled, pictures reduced), shapefiles record by record, KML and KMZ
/// (ground overlays included) between pauses. The result is handed to the
/// import of the format; null when the format has no such reader (it is
/// then read by the import itself). DXF, DWG and LAS have their own sliced
/// readers.
library;

import 'dart:typed_data';

import 'codepages.dart';
import 'dem_tiff.dart';
import 'geo.dart';
import 'geoimage.dart';
import 'kml.dart';
import 'safe_archive.dart';
import 'shp.dart';
import 'work_slicer.dart';

/// Reads [bytes] of file [name] in slices of [slicer]: a [GeoTiffDem], a
/// [GeoImage], a [ShpImportResult], a [KmlImportResult], or null.
Future<Object?> readImportAsync(String name, Uint8List bytes, WorkSlicer slicer, {GeoReference? georef}) async {
  final lower = name.toLowerCase();
  if (lower.endsWith('.tif') || lower.endsWith('.tiff')) {
    final dem = await GeoTiffDemReader.readAsync(bytes, slicer, georef: georef);
    if (dem != null) return dem;
    if (GeoImageReader.isLargeTiff(bytes)) return GeoImageReader.readLargeTiff(name, bytes, slicer: slicer);
    await slicer.pause(0.1);
    return GeoImageReader.read(name, bytes);
  }
  if (lower.endsWith('.shp')) return ShpReader.parseAnyAsync(name, bytes, slicer, georef: georef);
  if (lower.endsWith('.zip')) {
    // one shapefile in the zip (several are read by the import, one by one)
    final shps = openZip(bytes).files.where((f) => f.name.toLowerCase().endsWith('.shp')).length;
    if (shps == 1) return ShpReader.parseAnyAsync(name, bytes, slicer, georef: georef);
    return null;
  }
  if (lower.endsWith('.kmz')) {
    await slicer.pause(0.05);
    final r = KmlReader.parseKmz(bytes, georef: georef);
    await slicer.pause(0.9);
    return r;
  }
  if (lower.endsWith('.kml')) {
    await slicer.pause(0.05);
    final r = KmlReader.parse(decodeTextBytes(bytes), georef: georef);
    await slicer.pause(0.9);
    return r;
  }
  return null;
}
