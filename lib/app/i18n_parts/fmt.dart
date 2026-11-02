part of '../i18n.dart';

/// Strings added in 1.6.0 for file formats and online data: (pt, en, es), merged into the table after
/// the base strings (a key repeated in another part is a compile-time error).
const _fmt = <String, (String, String, String)>{
  // ---- import errors
  'imp.err.zip_too_large': (
    'O arquivo compactado se expande além do limite que o navegador aguenta (arquivo danificado ou malicioso)',
    'The compressed file expands beyond what the browser can hold (a damaged or malicious file)',
    'El archivo comprimido se expande más allá de lo que el navegador soporta (archivo dañado o malicioso)',
  ),
  'imp.err.tiff_predictor_unsupported': (
    'MDT em formato ou compressão não suportados: salve-o sem compressão, em LZW ou em Deflate',
    'Elevation raster in an unsupported layout or compression: save it uncompressed, as LZW or as Deflate',
    'MDT en formato o compresión no admitidos: guárdelo sin compresión, en LZW o en Deflate',
  ),
  // ---- import notes (after the summary; a detail follows in parentheses)
  'warn.dxf_resync': ('linhas fora do formato puladas', 'lines out of the format skipped', 'líneas fuera del formato omitidas'),
  'warn.dxf_paper_space': ('entidades do espaço papel (carimbo, molduras) deixadas de fora', 'paper space entities (title block, frames) left out', 'entidades del espacio papel (rótulo, marcos) dejadas fuera'),
  'warn.dxf_unsupported': ('entidades sem suporte deixadas de fora', 'unsupported entities left out', 'entidades no admitidas dejadas fuera'),
  'warn.dxf_blocks_truncated': (
    'blocos inseridos em excesso: desenho cortado no limite',
    'blocks inserted beyond the limit: drawing cut short',
    'bloques insertados en exceso: dibujo cortado en el límite',
  ),
  'warn.dxf_block_cycle': ('bloco que se insere em si mesmo desenhado uma vez', 'block inserting itself drawn once', 'bloque que se inserta en sí mismo dibujado una vez'),
  'warn.dxf_xref_missing': ('referência externa que não vem no arquivo', 'external reference not in the file', 'referencia externa que no viene en el archivo'),
  'warn.dxf_codepage_unsupported': (
    'página de código não suportada: textos lidos como ANSI_1252',
    'code page not supported: texts read as ANSI_1252',
    'página de códigos no admitida: textos leídos como ANSI_1252',
  ),
  'warn.dwg_units_unknown': ('unidades do DWG não indicadas: lido em metros', 'DWG units not given: read as metres', 'unidades del DWG no indicadas: leído en metros'),
  'warn.dwg_codepage_unsupported': (
    'página de código do DWG não suportada: textos lidos como ANSI_1252',
    'DWG code page not supported: texts read as ANSI_1252',
    'página de códigos del DWG no admitida: textos leídos como ANSI_1252',
  ),
  'warn.shp_truncated': ('shapefile danificado: lido até onde foi possível', 'damaged shapefile: read as far as possible', 'shapefile dañado: leído hasta donde fue posible'),
  'warn.dem_out_of_range': ('cotas além de ±10 km deixadas de fora', 'elevations beyond ±10 km left out', 'cotas más allá de ±10 km dejadas fuera'),
  'warn.dem_all_zero': ('todas as cotas do MDT são zero: confira o arquivo', 'every elevation of the raster is zero: check the file', 'todas las cotas del MDT son cero: revise el archivo'),
  'warn.cad_moved_to_georef': (
    'desenho em coordenadas UTM deslocado pela origem da georreferência do projeto',
    'drawing in UTM coordinates moved by the origin of the project georeference',
    'dibujo en coordenadas UTM desplazado por el origen de la georreferencia del proyecto',
  ),
  'warn.cad_far_from_georef': (
    'desenho em coordenadas UTM longe da área do projeto: mantido onde está (confira o fuso)',
    'drawing in UTM coordinates far from the project area: kept where it is (check the zone)',
    'dibujo en coordenadas UTM lejos del área del proyecto: mantenido donde está (revise el huso)',
  ),
  'warn.cad_utm_no_georef': (
    'o desenho parece estar em coordenadas UTM: defina a georreferência do projeto para vê-lo sobre o mapa',
    'the drawing looks like UTM coordinates: set the project georeference to see it on the map',
    'el dibujo parece estar en coordenadas UTM: defina la georreferencia del proyecto para verlo sobre el mapa',
  ),
  'warn.points_order': ('arquivo sem cabeçalho: colunas lidas na ordem', 'file without a header: columns read in the order', 'archivo sin encabezado: columnas leídas en el orden'),
  'warn.points_latlon_assumed': (
    'latitude e longitude cabem em ±90°: lidas na ordem',
    'latitude and longitude both fit ±90°: read in the order',
    'latitud y longitud caben en ±90°: leídas en el orden',
  ),
  // ---- import progress
  'fmt.import.reading': ('Lendo {f}…', 'Reading {f}…', 'Leyendo {f}…'),
  'fmt.import.cancelled': ('Importação cancelada: o projeto não mudou', 'Import cancelled: the project did not change', 'Importación cancelada: el proyecto no cambió'),
};
