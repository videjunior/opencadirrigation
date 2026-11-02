/// A page of a PDF plan as project entities: what [PdfReader] read from the
/// page (paths, texts and images in page points) scaled to drawing metres,
/// turned and placed, on layers of their own.
///
/// The scale is that of the paper: at 1:N one PDF unit (1/72 inch on the
/// sheet) is N × 0.0254 / 72 m; a plan whose units are not paper ones
/// (written by a CAD program in metres or millimetres) takes a factor
/// instead ([PdfImportOptions.metresPerUnit]). The bottom-left corner of
/// the page goes to [PdfImportOptions.origin]; the two-point align tool and
/// the georeference tools then fit the plan to known points.
///
/// Open paths of two points become lines, longer ones polylines, closed
/// paths closed polylines. Filled areas come in as their outlines (no
/// solid fill: on the dark canvas a filled plan would hide the design);
/// paper-white fills (masks behind texts) and a fill covering the whole
/// page (a background) are left out. Texts keep their height (the font
/// size on the page, scaled) and angle; images keep their four corners
/// (a mirrored image is flipped so that it reads the right way).
///
/// Layers: one per import ([PdfImportOptions.layer]), one per PDF layer
/// below it (`<layer>-<PDF layer>`) and, on request, one per colour
/// (`<layer>-RRGGBB`), since entities have no colour of their own. Their
/// colours are the plan's, made visible on the dark canvas: black and dark
/// greys turn light, dark colours are lightened.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import 'cad_drawing.dart' show cadTableName;
import 'image_decode.dart';
import 'pdf_reader.dart';

/// Metres on paper of one PDF unit (1/72 inch).
const pdfUnitPaperMetres = 0.0254 / 72;

/// Paper scales offered for PDF plans (1:N).
const pdfScales = [100, 200, 250, 500, 1000, 2000, 2500, 5000];

/// Most colour layers of one import (the rarer colours stay on the layer
/// of their PDF layer).
const _maxColourLayers = 32;

class PdfImportOptions {
  const PdfImportOptions({
    this.metresPerUnit = 100 * pdfUnitPaperMetres,
    this.origin = Pt.zero,
    this.rotationDeg = 0,
    this.vectors = true,
    this.texts = true,
    this.images = true,
    this.useLayers = true,
    this.hiddenLayers = false,
    this.byColour = false,
    this.layer = 'PDF',
    this.source = '',
  });

  /// Drawing metres of one PDF unit (see [atScale]).
  final double metresPerUnit;

  /// Where the bottom-left corner of the page goes (world metres).
  final Pt origin;

  /// Rotation of the plan about [origin], degrees counter-clockwise.
  final double rotationDeg;

  /// What to bring in: paths, texts, images.
  final bool vectors, texts, images;

  /// One layer per PDF layer (optional content group).
  final bool useLayers;

  /// Also the content of PDF layers that are off by default.
  final bool hiddenLayers;

  /// One layer per colour.
  final bool byColour;

  /// Layer of the import (and prefix of its PDF and colour layers).
  final String layer;

  /// File name, kept as the source of the images.
  final String source;

  /// Metres per PDF unit at the paper scale 1:[n].
  static double atScale(double n) => n * pdfUnitPaperMetres;

  PdfImportOptions copyWith({
    double? metresPerUnit,
    Pt? origin,
    double? rotationDeg,
    bool? vectors,
    bool? texts,
    bool? images,
    bool? useLayers,
    bool? hiddenLayers,
    bool? byColour,
    String? layer,
    String? source,
  }) => PdfImportOptions(
    metresPerUnit: metresPerUnit ?? this.metresPerUnit,
    origin: origin ?? this.origin,
    rotationDeg: rotationDeg ?? this.rotationDeg,
    vectors: vectors ?? this.vectors,
    texts: texts ?? this.texts,
    images: images ?? this.images,
    useLayers: useLayers ?? this.useLayers,
    hiddenLayers: hiddenLayers ?? this.hiddenLayers,
    byColour: byColour ?? this.byColour,
    layer: layer ?? this.layer,
    source: source ?? this.source,
  );
}

/// The entities of an imported page and the layers they are on.
class PdfImportResult {
  PdfImportResult(this.entities, this.layers, this.warnings);
  final List<Entity> entities;

  /// Every layer the entities use, with the colour a new one gets.
  final List<Layer> layers;
  final List<String> warnings;

  int get lines => entities.whereType<LineEntity>().length;
  int get polylines => entities.whereType<PolylineEntity>().length;
  int get texts => entities.whereType<TextEntity>().length;
  int get images => entities.whereType<ImageEntity>().length;

  Bounds get bounds {
    var b = Bounds.empty;
    for (final e in entities) {
      b = b.union(e.bounds);
    }
    return b;
  }
}

/// The entities of [page] placed with [o]; ids come from [newId].
PdfImportResult pdfPageEntities(PdfPageContent page, PdfImportOptions o, String Function() newId) {
  final t = Affine.scaling(o.metresPerUnit).then(Affine.rotation(degToRad(o.rotationDeg))).then(Affine.translation(o.origin));
  final base = o.layer.trim().isEmpty ? 'PDF' : cadTableName(o.layer.trim(), 'PDF');
  final pageArea = page.page.width * page.page.height;
  final warnings = <String>{};

  bool shown(bool hidden) => !hidden || o.hiddenLayers;
  bool background(PdfPathItem p) {
    if (p.stroked) return false;
    if (pdfLuminance(p.fillRgb) > 0.92) return true;
    final b = Bounds.ofPoints(p.points);
    return b.width * b.height > 0.85 * pageArea;
  }

  final paths = o.vectors
      ? [
          for (final p in page.paths)
            if (shown(p.hidden) && !background(p)) p,
        ]
      : const <PdfPathItem>[];
  final texts = o.texts
      ? [
          for (final x in page.texts)
            if (shown(x.hidden)) x,
        ]
      : const <PdfTextItem>[];
  final images = o.images
      ? [
          for (final im in page.images)
            if (shown(im.hidden) && im.bytes != null) im,
        ]
      : const <PdfImageItem>[];

  // the colours that get a layer of their own: the most used ones
  final colourLayers = <int>{};
  if (o.byColour) {
    final weight = <int, int>{};
    for (final p in paths) {
      weight[p.rgb] = (weight[p.rgb] ?? 0) + p.segments;
    }
    for (final x in texts) {
      weight[x.rgb] = (weight[x.rgb] ?? 0) + x.text.length;
    }
    final ranked = weight.keys.toList()..sort((a, b) => weight[b]!.compareTo(weight[a]!));
    colourLayers.addAll(ranked.take(_maxColourLayers));
    if (ranked.length > _maxColourLayers) warnings.add('pdf_colours_capped:$_maxColourLayers');
  }
  final colourUse = <String, Map<int, int>>{};
  String layerOf(String pdfLayer, int? rgb, int weight) {
    var name = base;
    if (o.useLayers && pdfLayer.trim().isNotEmpty) name = cadTableName('$base-${pdfLayer.trim()}', base);
    if (rgb != null && colourLayers.contains(rgb)) name = '$name-${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
    final use = colourUse.putIfAbsent(name, () => {});
    if (rgb != null) use[rgb] = (use[rgb] ?? 0) + weight;
    return name;
  }

  final out = <Entity>[];
  for (final im in images) {
    var c = im.corners;
    var bytes = im.bytes!;
    if ((c[1] - c[0]).cross(c[3] - c[0]) < 0) {
      // drawn mirrored: flipped top to bottom, the corners follow
      final flipped = _flipVertical(bytes, im.mime);
      if (flipped == null) {
        warnings.add('pdf_image_failed');
        continue;
      }
      bytes = flipped;
      c = [c[3], c[2], c[1], c[0]];
    }
    final p0 = t.apply(c[0]), p1 = t.apply(c[1]), p3 = t.apply(c[3]);
    final u = p1 - p0, v = p3 - p0;
    final w = u.length;
    if (w <= 0) continue;
    final h = u.cross(v).abs() / w;
    if (h <= 0) continue;
    if (u.dot(v).abs() > 0.01 * w * v.length) warnings.add('pdf_image_skewed');
    out.add(ImageEntity(id: newId(), layer: layerOf(im.layer, null, 0), origin: p0, width: w, height: h, rotationDeg: radToDeg(u.angle), mime: im.mime, data: bytes, source: o.source));
  }
  for (final p in paths) {
    final pts = [for (final q in p.points) t.apply(q)];
    final layer = layerOf(p.layer, p.rgb, p.segments);
    if (p.closed && pts.length >= 3) {
      out.add(PolylineEntity(id: newId(), layer: layer, points: pts, closed: true));
    } else if (pts.length == 2) {
      out.add(LineEntity(id: newId(), layer: layer, a: pts[0], b: pts[1]));
    } else if (pts.length > 2) {
      out.add(PolylineEntity(id: newId(), layer: layer, points: pts));
    }
  }
  for (final x in texts) {
    out.add(
      TextEntity(
        id: newId(),
        layer: layerOf(x.layer, x.rgb, x.text.length),
        position: t.apply(x.origin),
        text: x.text,
        height: x.height * o.metresPerUnit,
        rotationDeg: _degrees(x.angleDeg + o.rotationDeg),
      ),
    );
  }
  final layers = <Layer>[for (final e in colourUse.entries) Layer(name: e.key, color: pdfCanvasColour(e.value.isEmpty ? 0 : (e.value.entries.reduce((a, b) => b.value > a.value ? b : a)).key))];
  return PdfImportResult(out, layers, warnings.toList());
}

/// Adds the entities of [page] to [project] with the layers it lacks (see
/// [addPdfEntities]). Call it inside the controller's `mutate`, so that the
/// import is one undo step.
PdfImportResult addPdfPage(Project project, PdfPageContent page, PdfImportOptions o) {
  final r = pdfPageEntities(page, o, project.newId);
  addPdfEntities(project, r);
  return r;
}

/// Adds converted entities to [project]: the layers it lacks, the images
/// under the drawing (as image import does), the rest on top.
void addPdfEntities(Project project, PdfImportResult r) {
  for (final l in r.layers) {
    if (project.findLayer(l.name) == null) project.layers.add(l);
  }
  project.entities.insertAll(0, r.entities.whereType<ImageEntity>());
  project.entities.addAll(r.entities.where((e) => e is! ImageEntity));
}

/// The layer of an import of [fileName]: `PDF-<name without extension>`.
String pdfLayerName(String fileName) {
  var stem = fileName.split(RegExp(r'[/\\]')).last;
  final dot = stem.lastIndexOf('.');
  if (dot > 0) stem = stem.substring(0, dot);
  stem = stem.trim();
  if (stem.length > 40) stem = stem.substring(0, 40);
  return cadTableName(stem.isEmpty ? 'PDF' : 'PDF-$stem', 'PDF');
}

/// The scale written on the sheet (`ESCALA 1:500`, `Scale 1/200`, a lone
/// `1:250`), or null. A ratio counts when its text names a scale or is the
/// ratio alone, so that times and dates are not taken for one.
int? pdfScaleOnSheet(PdfPageContent page) {
  final ratio = RegExp(r'(?:^|[^\d.,])1\s*[:/]\s*(\d{2,6})(?![\d.,/:])');
  final word = RegExp(r'esc|scal|échelle|echelle|ma(ß|ss)stab|scala|skala|縮尺|比例', caseSensitive: false);
  final count = <int, int>{};
  for (final x in page.texts) {
    final s = x.text.trim();
    if (s.length > 80) continue;
    final named = word.hasMatch(s);
    for (final m in ratio.allMatches(s)) {
      final n = int.parse(m.group(1)!);
      if (n < 10 || n > 100000) continue;
      final alone = s.replaceAll(RegExp(r'\s'), '').length <= m.group(0)!.replaceAll(RegExp(r'\s'), '').length + 1;
      if (named || alone) count[n] = (count[n] ?? 0) + (named ? 2 : 1);
    }
  }
  if (count.isEmpty) return null;
  return (count.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
}

/// Relative luminance (0 black … 1 white) of 0xRRGGBB.
double pdfLuminance(int rgb) => (0.2126 * ((rgb >> 16) & 0xFF) + 0.7152 * ((rgb >> 8) & 0xFF) + 0.0722 * (rgb & 0xFF)) / 255;

/// ARGB that shows a plan colour (0xRRGGBB) on the dark canvas: greys are
/// mirrored (black becomes a light grey, light greys darker but still
/// visible), dark colours are lightened keeping their hue.
int pdfCanvasColour(int rgb) {
  final r = ((rgb >> 16) & 0xFF) / 255, g = ((rgb >> 8) & 0xFF) / 255, b = (rgb & 0xFF) / 255;
  final mx = math.max(r, math.max(g, b)), mn = math.min(r, math.min(g, b));
  if (mx - mn < 0.12) {
    final l = (mx + mn) / 2;
    final v = ((0.85 - 0.45 * l) * 255).round();
    return 0xFF000000 + v * 0x10000 + v * 0x100 + v;
  }
  // HSL: lightness raised to 0.6 at least, more for the dim hues (blue)
  final l = (mx + mn) / 2;
  final d = mx - mn;
  final s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
  double h;
  if (mx == r) {
    h = ((g - b) / d) % 6;
  } else if (mx == g) {
    h = (b - r) / d + 2;
  } else {
    h = (r - g) / d + 4;
  }
  h /= 6;
  int c(double v) => (v.clamp(0.0, 1.0) * 255).round();
  int fromHsl(double light) {
    final q = light < 0.5 ? light * (1 + s) : light + s - light * s, p = 2 * light - q;
    double hue(double t) {
      if (t < 0) t += 1;
      if (t > 1) t -= 1;
      if (t < 1 / 6) return p + (q - p) * 6 * t;
      if (t < 1 / 2) return q;
      if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
      return p;
    }

    return c(hue(h + 1 / 3)) * 0x10000 + c(hue(h)) * 0x100 + c(hue(h - 1 / 3));
  }

  var light = math.max(l, 0.6);
  var out = fromHsl(light);
  while (pdfLuminance(out) < 0.35 && light < 0.85) {
    light += 0.05;
    out = fromHsl(light);
  }
  return 0xFF000000 + out;
}

double _degrees(double a) {
  var d = a % 360;
  if (d < 0) d += 360;
  return d;
}

/// [bytes] decoded, or null when the decoder cannot or will not read them.
img.Image? _decodeOrNull(Uint8List bytes) {
  try {
    return decodeImageSafe(bytes);
  } on FormatException {
    return null;
  }
}

/// [bytes] (PNG or JPEG) turned upside down, in the same format.
Uint8List? _flipVertical(Uint8List bytes, String mime) {
  final im = _decodeOrNull(bytes);
  if (im == null) return null;
  final f = img.flipVertical(im);
  return mime == 'image/jpeg' ? img.encodeJpg(f, quality: 90) : img.encodePng(f);
}
