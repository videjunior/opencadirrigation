part of 'pdf_reader.dart';

// Colours and images of the PDF reader: colour spaces turned into RGB,
// the tint transforms of spot colours, and image samples re-encoded as PNG
// (JPEG passed through).

const _csGray = 0, _csRgb = 1, _csCmyk = 2, _csLab = 3, _csIndexed = 4, _csTint = 5, _csPattern = 6;

/// What pattern fills are drawn with (patterns are not interpreted).
const _patternRgb = 0x808080;

/// Most pixels and largest side of a decoded image; larger ones are
/// reduced (by whole factors, averaging) for the canvas.
const _maxImagePixels = 40000000, _maxImageSide = 16384;

/// A colour space, enough to turn colours and samples into RGB: the device
/// spaces (ICC-based and calibrated ones by their component count), Lab,
/// Indexed, Separation and DeviceN (through their tint transform when it is
/// an exponential, stitching or sampled function, else as a grey of the
/// tint) and Pattern (grey).
class _Cs {
  _Cs(this.kind, this.n, {this.base, this.hival = 0, this.lookup, this.fn, this.white = const [0.9505, 1, 1.089], this.range = const [-100, 100, -100, 100], this.none = false});
  static final gray = _Cs(_csGray, 1);
  static final rgb = _Cs(_csRgb, 3);
  static final cmyk = _Cs(_csCmyk, 4);
  static final pattern = _Cs(_csPattern, 1);

  final int kind;

  /// Components of a colour (Indexed: 1, the index).
  final int n;
  final _Cs? base;
  final int hival;
  final Uint8List? lookup;
  final _Fn? fn;

  /// Lab white point and a*, b* ranges.
  final List<double> white, range;

  /// The Separation /None, which paints nothing.
  final bool none;

  int get components => n;

  /// RGB of every index of an Indexed space.
  late final Uint8List palette = _buildPalette();

  /// The colour set by `cs`/`CS` (black, or the first index).
  int get initial => switch (kind) {
    _csIndexed => rgbOf(const [0.0], 0, 1),
    _csTint => rgbOf(List.filled(n, 1.0), 0, n),
    _csPattern => _patternRgb,
    _csLab => 0,
    _ => 0,
  };

  /// RGB (0xRRGGBB) of the colour whose components are c[at..end) (missing
  /// ones read as 0).
  int rgbOf(List<double> c, int at, int end) {
    double v(int i) {
      final k = at + i;
      return k >= 0 && k < end && k < c.length ? c[k] : 0;
    }

    switch (kind) {
      case _csGray:
        final g = v(0);
        return _rgb(g, g, g);
      case _csRgb:
        return _rgb(v(0), v(1), v(2));
      case _csCmyk:
        final k = v(3);
        return _rgb((1 - v(0)) * (1 - k), (1 - v(1)) * (1 - k), (1 - v(2)) * (1 - k));
      case _csLab:
        return _labRgb(v(0), v(1), v(2), white);
      case _csIndexed:
        final i = v(0).round().clamp(0, hival);
        final p = palette;
        return 3 * i + 2 < p.length ? (p[3 * i] << 16) | (p[3 * i + 1] << 8) | p[3 * i + 2] : 0;
      case _csTint:
        if (none) return 0xFFFFFF;
        final tints = [for (var i = 0; i < n; i++) v(i)];
        final f = fn;
        final b = base;
        if (f != null && b != null) {
          final out = f.eval(tints);
          if (out.isNotEmpty) return b.rgbOf(out, 0, out.length);
        }
        // no usable tint transform: full ink dark, none white
        final t = tints.fold(0.0, (s, x) => s + x) / n;
        return _rgb(1 - t, 1 - t, 1 - t);
      default:
        return _patternRgb;
    }
  }

  Uint8List _buildPalette() {
    final b = base ?? _Cs.rgb;
    final count = hival + 1;
    final out = Uint8List(count * 3);
    final lut = lookup ?? Uint8List(0);
    final comp = List<double>.filled(b.n, 0);
    for (var i = 0; i < count; i++) {
      for (var j = 0; j < b.n; j++) {
        final k = i * b.n + j;
        final x = k < lut.length ? lut[k] / 255 : 0.0;
        comp[j] = b.kind == _csLab ? (j == 0 ? x * 100 : b.range[2 * (j - 1)] + x * (b.range[2 * (j - 1) + 1] - b.range[2 * (j - 1)])) : x;
      }
      final rgb = b.rgbOf(comp, 0, b.n);
      out[3 * i] = (rgb >> 16) & 0xFF;
      out[3 * i + 1] = (rgb >> 8) & 0xFF;
      out[3 * i + 2] = rgb & 0xFF;
    }
    return out;
  }
}

int _byte(double v) => v.isNaN ? 0 : (v.clamp(0.0, 1.0) * 255).round();

int _rgb(double r, double g, double b) => (_byte(r) << 16) | (_byte(g) << 8) | _byte(b);

/// CIE L*a*b* → sRGB (the white point taken as D65's; no adaptation).
int _labRgb(double l, double a, double b, List<double> white) {
  double f(double t) => t > 6 / 29 ? t * t * t : 3 * (6 / 29) * (6 / 29) * (t - 4 / 29);
  final fy = (l + 16) / 116;
  final wx = white.isNotEmpty ? white[0] : 0.9505, wy = white.length > 1 ? white[1] : 1.0, wz = white.length > 2 ? white[2] : 1.089;
  final x = wx * f(fy + a / 500), y = wy * f(fy), z = wz * f(fy - b / 200);
  double gamma(double c) => c <= 0.0031308 ? 12.92 * c : 1.055 * math.pow(c, 1 / 2.4) - 0.055;
  return _rgb(gamma(3.2406 * x - 1.5372 * y - 0.4986 * z), gamma(-0.9689 * x + 1.8758 * y + 0.0415 * z), gamma(0.0557 * x - 0.2040 * y + 1.0570 * z));
}

/// A function of one input (7.10): exponential (type 2), stitching
/// (type 3) and sampled (type 0); an array of them gives one output each.
class _Fn {
  _Fn._(this.type);
  final int type;
  List<double> domain = const [0, 1];
  List<double> c0 = const [0], c1 = const [1];
  double exponent = 1;
  List<_Fn> parts = const [];
  List<double> bounds = const [], encode = const [];
  List<double> samples = const [], decode = const [];
  int size = 0, outputs = 0;

  static _Fn? parse(PdfReader doc, Object? o, [int depth = 0]) {
    if (depth > 6) return null;
    final v = doc._resolve(o);
    if (v is List) {
      final fns = [for (final e in v) parse(doc, e, depth + 1)];
      if (fns.isEmpty || fns.any((f) => f == null)) return null;
      return _Fn._(-1)..parts = fns.cast<_Fn>();
    }
    final d = doc._dict(v);
    if (d == null) return null;
    final type = doc._int(d['FunctionType']) ?? -2;
    final f = _Fn._(type)..domain = doc._numbers(d['Domain']) ?? const [0, 1];
    switch (type) {
      case 2:
        f.c0 = doc._numbers(d['C0']) ?? const [0];
        f.c1 = doc._numbers(d['C1']) ?? const [1];
        f.exponent = doc._num(d['N']) ?? 1;
        return f;
      case 3:
        final fns = [for (final e in doc._array(d['Functions']) ?? const []) parse(doc, e, depth + 1)];
        if (fns.isEmpty || fns.any((x) => x == null)) return null;
        f.parts = fns.cast<_Fn>();
        f.bounds = doc._numbers(d['Bounds']) ?? const [];
        f.encode =
            doc._numbers(d['Encode']) ??
            [
              for (var i = 0; i < fns.length; i++) ...[0.0, 1.0],
            ];
        return f;
      case 0:
        if (v is! _Stream) return null;
        final sizes = doc._numbers(d['Size']);
        final range = doc._numbers(d['Range']);
        final bps = doc._int(d['BitsPerSample']) ?? 8;
        if (sizes == null || sizes.length != 1 || range == null || range.length < 2 || !const [1, 2, 4, 8, 12, 16, 24, 32].contains(bps)) return null;
        f.size = sizes[0].toInt();
        f.outputs = range.length ~/ 2;
        f.encode = doc._numbers(d['Encode']) ?? [0, f.size - 1.0];
        f.decode = doc._numbers(d['Decode']) ?? range;
        final data = doc._decodeStream(v);
        final count = f.size * f.outputs;
        if (count <= 0 || count > 1 << 20) return null;
        final out = List<double>.filled(count, 0);
        final maxV = math.pow(2, bps) - 1;
        var bit = 0;
        for (var i = 0; i < count; i++) {
          var s = 0;
          for (var k = 0; k < bps; k++) {
            final byte = bit >> 3;
            final b = byte < data.length ? (data[byte] >> (7 - (bit & 7))) & 1 : 0;
            s = s * 2 + b;
            bit++;
          }
          final o = i % f.outputs;
          out[i] = f.decode.length > 2 * o + 1 ? f.decode[2 * o] + s / maxV * (f.decode[2 * o + 1] - f.decode[2 * o]) : s / maxV;
        }
        f.samples = out;
        return f;
    }
    return null;
  }

  List<double> eval(List<double> input) {
    if (type == -1) return [for (final p in parts) ...p.eval(input)];
    final d0 = domain.isNotEmpty ? domain[0] : 0.0, d1 = domain.length > 1 ? domain[1] : 1.0;
    final x = (input.isEmpty ? 0.0 : input[0]).clamp(math.min(d0, d1), math.max(d0, d1)).toDouble();
    switch (type) {
      case 2:
        final t = math.pow(x, exponent).toDouble();
        final n = math.max(c0.length, c1.length);
        return [for (var i = 0; i < n; i++) (i < c0.length ? c0[i] : 0) + t * ((i < c1.length ? c1[i] : 1) - (i < c0.length ? c0[i] : 0))];
      case 3:
        final k = parts.length;
        var i = 0;
        while (i < bounds.length && i < k - 1 && x >= bounds[i]) {
          i++;
        }
        final lo = i == 0 ? d0 : bounds[i - 1], hi = i < bounds.length ? bounds[i] : d1;
        final e0 = 2 * i < encode.length ? encode[2 * i] : 0.0, e1 = 2 * i + 1 < encode.length ? encode[2 * i + 1] : 1.0;
        final t = hi == lo ? e0 : e0 + (x - lo) * (e1 - e0) / (hi - lo);
        return parts[i].eval([t]);
      case 0:
        final e0 = encode.isNotEmpty ? encode[0] : 0.0, e1 = encode.length > 1 ? encode[1] : size - 1.0;
        final e = (d1 == d0 ? e0 : e0 + (x - d0) * (e1 - e0) / (d1 - d0)).clamp(0.0, size - 1.0);
        final i0 = e.floor(), i1 = math.min(size - 1, i0 + 1);
        final w = e - i0;
        return [for (var o = 0; o < outputs; o++) samples[i0 * outputs + o] * (1 - w) + samples[i1 * outputs + o] * w];
    }
    return const [];
  }
}

extension _ColorSpaces on PdfReader {
  _Cs _colorSpace(Object? spec, Map<String, Object?>? res, [int depth = 0]) {
    if (depth > 8) return _Cs.gray;
    final v = _resolve(spec);
    if (v is _Name) {
      final known = _deviceSpace(v.v);
      if (known != null) return known;
      final named = _dict(res?['ColorSpace'])?[v.v];
      return named == null ? _Cs.gray : _colorSpace(named, res, depth + 1);
    }
    if (v is! List || v.isEmpty) return _Cs.gray;
    final family = _name(v[0]) ?? '';
    final known = _deviceSpace(family);
    if (known != null) return known;
    switch (family) {
      case 'ICCBased':
        final s = v.length > 1 ? _dict(v[1]) : null;
        final n = _int(s?['N']) ?? 3;
        if (n != 1 && n != 3 && n != 4 && s?['Alternate'] != null) return _colorSpace(s!['Alternate'], res, depth + 1);
        return n == 1 ? _Cs.gray : (n == 4 ? _Cs.cmyk : _Cs.rgb);
      case 'Lab':
        final d = v.length > 1 ? _dict(v[1]) : null;
        return _Cs(_csLab, 3, white: _numbers(d?['WhitePoint']) ?? const [0.9505, 1, 1.089], range: _numbers(d?['Range']) ?? const [-100, 100, -100, 100]);
      case 'Indexed' || 'I':
        if (v.length < 4) return _Cs.gray;
        final base = _colorSpace(v[1], res, depth + 1);
        final hival = (_int(v[2]) ?? 0).clamp(0, 255);
        final l = _resolve(v[3]);
        final lookup = l is _Str ? l.b : (l is _Stream ? _decodeStream(l) : Uint8List(0));
        return _Cs(_csIndexed, 1, base: base, hival: hival, lookup: lookup);
      case 'Separation' || 'DeviceN':
        final names = family == 'Separation' ? [v.length > 1 ? _name(v[1]) : null] : [for (final e in _array(v.length > 1 ? v[1] : null) ?? const []) _name(e)];
        final alt = v.length > 2 ? _colorSpace(v[2], res, depth + 1) : _Cs.gray;
        final fn = v.length > 3 ? _Fn.parse(this, v[3]) : null;
        return _Cs(_csTint, math.max(1, names.length), base: alt, fn: fn, none: names.every((n) => n == 'None'));
    }
    return _Cs.gray;
  }

  static _Cs? _deviceSpace(String name) => switch (name) {
    'DeviceGray' || 'G' || 'CalGray' => _Cs.gray,
    'DeviceRGB' || 'RGB' || 'CalRGB' => _Cs.rgb,
    'DeviceCMYK' || 'CMYK' => _Cs.cmyk,
    'Pattern' => _Cs.pattern,
    _ => null,
  };
}

// ---------------------------------------------------------------- images

/// A decoded image: encoded bytes ready for the canvas.
class _Raster {
  _Raster(this.bytes, this.mime, this.width, this.height);
  final Uint8List bytes;
  final String mime;
  final int width, height;
}

/// Decodes an image XObject or inline image ([dict], encoded [raw] data).
/// Throws [_Unsupported] for JPEG 2000 and JBIG2 data.
_Raster? _decodeImage(_Interp it, Map<String, Object?> dict, Uint8List raw, Map<String, Object?>? res) {
  final doc = it.doc;
  final w = doc._int(dict['Width']) ?? 0, h = doc._int(dict['Height']) ?? 0;
  if (w <= 0 || h <= 0) return null;
  if (w.toDouble() * h > 400e6) throw const _TooLarge();
  final (names, parms) = doc._filters(dict);
  var data = raw;
  var i = 0;
  for (; i < names.length; i++) {
    final f = names[i];
    if (f == 'DCTDecode' || f == 'JPXDecode' || f == 'JBIG2Decode' || f == 'CCITTFaxDecode') break;
    data = doc._filter(f, data, parms[i]);
  }
  final codec = i < names.length ? names[i] : null;
  if (codec == 'JPXDecode' || codec == 'JBIG2Decode') throw _Unsupported(codec!);
  final mask = doc._bool(dict['ImageMask']) ?? false;
  final cs = mask ? _Cs.gray : it.colorSpace(dict['ColorSpace'], res);
  final decode = doc._numbers(dict['Decode']);
  if (codec == 'DCTDecode') return _jpeg(it, data, dict, decode);
  var bpc = mask ? 1 : (doc._int(dict['BitsPerComponent']) ?? 8);
  var width = w;
  if (codec == 'CCITTFaxDecode') {
    final (gray, cols) = _ccitt(doc, data, parms[i], w, h);
    data = gray;
    width = cols;
    bpc = 8;
  }
  if (!const [1, 2, 4, 8, 16].contains(bpc)) return null;
  return _fromSamples(it, dict, data, width, h, bpc, cs, decode, mask);
}

/// Samples → pixels → PNG: decode arrays, colour conversion, stencil masks
/// (the fill colour where the sample is 0), soft masks, stencil /Mask and
/// colour-key masking; images beyond [_maxImagePixels] are reduced.
_Raster? _fromSamples(_Interp it, Map<String, Object?> dict, Uint8List data, int w, int h, int bpc, _Cs cs, List<double>? decode, bool mask) {
  final doc = it.doc;
  final comps = mask ? 1 : cs.components;
  final maxV = (1 << bpc) - 1;
  final dmin = Float64List(comps), dmax = Float64List(comps);
  for (var k = 0; k < comps; k++) {
    var lo = 0.0, hi = 1.0;
    if (cs.kind == _csIndexed && !mask) hi = maxV.toDouble();
    if (cs.kind == _csLab && !mask) {
      lo = k == 0 ? 0 : cs.range[2 * (k - 1)];
      hi = k == 0 ? 100 : cs.range[2 * (k - 1) + 1];
    }
    if (decode != null && decode.length >= 2 * k + 2) {
      lo = decode[2 * k];
      hi = decode[2 * k + 1];
    }
    dmin[k] = lo;
    dmax[k] = hi;
  }
  var f = 1;
  while (((w + f - 1) ~/ f) * ((h + f - 1) ~/ f) > _maxImagePixels || (w + f - 1) ~/ f > _maxImageSide || (h + f - 1) ~/ f > _maxImageSide) {
    f++;
  }
  if (f > 1) it.warnings.add('pdf_image_reduced');
  final dw = (w + f - 1) ~/ f, dh = (h + f - 1) ~/ f;
  final soft = mask ? null : _alphaOf(it, dict, dw, dh);
  final keyRanges = mask ? null : doc._numbers(dict['Mask']);
  final colorKey = keyRanges != null && keyRanges.length >= 2 * comps ? keyRanges : null;
  final grayOut = !mask && (cs.kind == _csGray || (cs.kind == _csIndexed && cs.base?.kind == _csGray));
  final alphaOut = mask || soft != null || colorKey != null;
  final ch = (grayOut ? 1 : 3) + (alphaOut ? 1 : 0);
  final out = Uint8List(dw * dh * ch);
  final rowBytes = (w * comps * bpc + 7) ~/ 8;
  final fill = it.gs.fillRgb;
  final fr = (fill >> 16) & 0xFF, fg = (fill >> 8) & 0xFF, fb = fill & 0xFF;
  final palette = cs.kind == _csIndexed && !mask ? cs.palette : null;
  final identity = decode == null && cs.kind != _csLab;
  final comp = List<double>.filled(comps, 0);
  final rawS = Int32List(comps);
  final px = Int32List(4);
  // a lookup per sample value for the slow spaces of one component
  final lut = !mask && comps == 1 && bpc <= 8 && (cs.kind == _csTint || cs.kind == _csLab) ? List<int?>.filled(maxV + 1, null) : null;
  final sums = f > 1 ? Int32List(dw * ch) : null;
  final counts = f > 1 ? Int32List(dw) : null;
  for (var y = 0; y < h; y++) {
    final row = y * rowBytes;
    final dy = y ~/ f;
    for (var x = 0; x < w; x++) {
      for (var k = 0; k < comps; k++) {
        final idx = x * comps + k;
        int s;
        if (bpc == 8) {
          final p = row + idx;
          s = p < data.length ? data[p] : 0;
        } else if (bpc == 16) {
          final p = row + 2 * idx;
          s = p + 1 < data.length ? (data[p] << 8) | data[p + 1] : 0;
        } else {
          final bit = idx * bpc;
          final p = row + (bit >> 3);
          s = p < data.length ? (data[p] >> (8 - bpc - (bit & 7))) & maxV : 0;
        }
        rawS[k] = s;
        comp[k] = dmin[k] + s * (dmax[k] - dmin[k]) / maxV;
      }
      var a = 255;
      if (mask) {
        px[0] = fr;
        px[1] = fg;
        px[2] = fb;
        a = comp[0] < 0.5 ? 255 : 0;
      } else {
        switch (cs.kind) {
          case _csGray:
            px[0] = identity && bpc == 8 ? rawS[0] : _byte(comp[0]);
          case _csRgb:
            if (identity && bpc == 8) {
              px[0] = rawS[0];
              px[1] = rawS[1];
              px[2] = rawS[2];
            } else {
              px[0] = _byte(comp[0]);
              px[1] = _byte(comp[1]);
              px[2] = _byte(comp[2]);
            }
          case _csIndexed:
            final i = comp[0].round().clamp(0, cs.hival);
            if (grayOut) {
              px[0] = palette![3 * i];
            } else {
              px[0] = palette![3 * i];
              px[1] = palette[3 * i + 1];
              px[2] = palette[3 * i + 2];
            }
          default:
            final v = lut == null ? cs.rgbOf(comp, 0, comps) : (lut[rawS[0]] ??= cs.rgbOf(comp, 0, comps));
            px[0] = (v >> 16) & 0xFF;
            px[1] = (v >> 8) & 0xFF;
            px[2] = v & 0xFF;
        }
        if (colorKey != null) {
          var keyed = true;
          for (var k = 0; k < comps; k++) {
            if (rawS[k] < colorKey[2 * k] || rawS[k] > colorKey[2 * k + 1]) {
              keyed = false;
              break;
            }
          }
          if (keyed) a = 0;
        }
      }
      final colours = grayOut ? 1 : 3;
      if (sums == null) {
        final o = (y * dw + x) * ch;
        for (var c = 0; c < colours; c++) {
          out[o + c] = px[c];
        }
        if (alphaOut) out[o + colours] = a;
      } else {
        final dx = x ~/ f;
        final o = dx * ch;
        for (var c = 0; c < colours; c++) {
          sums[o + c] += px[c];
        }
        if (alphaOut) sums[o + colours] += a;
        counts![dx]++;
      }
    }
    if (sums != null && (y % f == f - 1 || y == h - 1)) {
      for (var dx = 0; dx < dw; dx++) {
        final n = math.max(1, counts![dx]);
        for (var c = 0; c < ch; c++) {
          out[(dy * dw + dx) * ch + c] = sums[dx * ch + c] ~/ n;
        }
      }
      sums.fillRange(0, sums.length, 0);
      counts!.fillRange(0, counts.length, 0);
    }
  }
  if (soft != null) {
    final colours = grayOut ? 1 : 3;
    for (var i = 0; i < dw * dh; i++) {
      final o = i * ch + colours;
      out[o] = colorKey != null || mask ? (out[o] * soft[i]) ~/ 255 : soft[i];
    }
  }
  final image = img.Image.fromBytes(width: dw, height: dh, bytes: out.buffer, numChannels: ch);
  return _Raster(img.encodePng(image), 'image/png', dw, dh);
}

/// The alpha of an image at [dw] × [dh]: its soft mask (/SMask, grey
/// values), or its stencil /Mask (painted where the mask sample is 0).
Uint8List? _alphaOf(_Interp it, Map<String, Object?> dict, int dw, int dh) {
  final doc = it.doc;
  final sm = doc._resolve(dict['SMask']);
  final mk = doc._resolve(dict['Mask']);
  final s = sm is _Stream ? sm : (mk is _Stream ? mk : null);
  if (s == null) return null;
  final stencil = !identical(s, sm);
  final mw = doc._int(s.dict['Width']) ?? 0, mh = doc._int(s.dict['Height']) ?? 0;
  if (mw <= 0 || mh <= 0 || mw.toDouble() * mh > 200e6) return null;
  Uint8List data;
  var width = mw;
  var bpc = stencil ? 1 : (doc._int(s.dict['BitsPerComponent']) ?? 8);
  try {
    final (names, parms) = doc._filters(s.dict);
    data = s.raw;
    var i = 0;
    for (; i < names.length; i++) {
      if (names[i] == 'DCTDecode' || names[i] == 'CCITTFaxDecode' || names[i] == 'JPXDecode' || names[i] == 'JBIG2Decode') break;
      data = doc._filter(names[i], data, parms[i]);
    }
    if (i < names.length) {
      if (names[i] == 'CCITTFaxDecode') {
        final (g, cols) = _ccitt(doc, data, parms[i], mw, mh);
        data = g;
        width = cols;
        bpc = 8;
      } else if (names[i] == 'DCTDecode') {
        final im = img.decodeJpg(data);
        if (im == null) return null;
        data = im.convert(format: img.Format.uint8, numChannels: 1).toUint8List();
        width = im.width;
        bpc = 8;
      } else {
        return null;
      }
    }
  } on _TooLarge {
    rethrow;
  } on Object {
    return null;
  }
  if (!const [1, 2, 4, 8, 16].contains(bpc)) return null;
  final decode = doc._numbers(s.dict['Decode']);
  final lo = decode != null && decode.length >= 2 ? decode[0] : 0.0, hi = decode != null && decode.length >= 2 ? decode[1] : 1.0;
  final maxV = (1 << bpc) - 1;
  final rowBytes = (width * bpc + 7) ~/ 8;
  final out = Uint8List(dw * dh);
  for (var y = 0; y < dh; y++) {
    final sy = math.min(mh - 1, (y * mh) ~/ dh);
    for (var x = 0; x < dw; x++) {
      final sx = math.min(width - 1, (x * width) ~/ dw);
      int v;
      if (bpc == 8) {
        final p = sy * rowBytes + sx;
        v = p < data.length ? data[p] : 0;
      } else if (bpc == 16) {
        final p = sy * rowBytes + 2 * sx;
        v = p + 1 < data.length ? (data[p] << 8) | data[p + 1] : 0;
      } else {
        final bit = sx * bpc;
        final p = sy * rowBytes + (bit >> 3);
        v = p < data.length ? (data[p] >> (8 - bpc - (bit & 7))) & maxV : 0;
      }
      final t = lo + v * (hi - lo) / maxV;
      out[y * dw + x] = stencil ? (t < 0.5 ? 255 : 0) : _byte(t);
    }
  }
  return out;
}

/// DCTDecode data: passed through when the canvas can show it as it is
/// (grey or RGB, no mask, no inverting decode array); otherwise decoded
/// (CMYK) and encoded again, with the alpha of its mask as PNG.
_Raster? _jpeg(_Interp it, Uint8List data, Map<String, Object?> dict, List<double>? decode) {
  final doc = it.doc;
  final info = _jpegInfo(data);
  final masked = doc._resolve(dict['SMask']) is _Stream || doc._resolve(dict['Mask']) is _Stream;
  final inverted = decode != null && decode.length >= 2 && decode[0] > decode[1];
  if (info != null && (info.$3 == 1 || info.$3 == 3) && !masked && !inverted) return _Raster(data, 'image/jpeg', info.$1, info.$2);
  final im = img.decodeJpg(data);
  if (im == null) return info != null && info.$3 != 4 ? _Raster(data, 'image/jpeg', info.$1, info.$2) : null;
  var pic = im.convert(format: img.Format.uint8, numChannels: 3);
  if (inverted && info?.$3 != 4) pic = img.invert(pic);
  final alpha = masked ? _alphaOf(it, dict, pic.width, pic.height) : null;
  if (alpha == null) return _Raster(img.encodeJpg(pic, quality: 90), 'image/jpeg', pic.width, pic.height);
  final rgb = pic.getBytes(order: img.ChannelOrder.rgb);
  final n = pic.width * pic.height;
  final rgba = Uint8List(4 * n);
  for (var i = 0; i < n; i++) {
    rgba[4 * i] = rgb[3 * i];
    rgba[4 * i + 1] = rgb[3 * i + 1];
    rgba[4 * i + 2] = rgb[3 * i + 2];
    rgba[4 * i + 3] = alpha[i];
  }
  return _Raster(img.encodePng(img.Image.fromBytes(width: pic.width, height: pic.height, bytes: rgba.buffer, numChannels: 4)), 'image/png', pic.width, pic.height);
}

/// Width, height and components of a JPEG (its first frame header).
(int, int, int)? _jpegInfo(Uint8List b) {
  if (b.length < 4 || b[0] != 0xFF || b[1] != 0xD8) return null;
  var p = 2;
  while (p + 3 < b.length) {
    if (b[p] != 0xFF) {
      p++;
      continue;
    }
    final m = b[p + 1];
    if (m == 0xFF) {
      p++;
      continue;
    }
    if (m == 0xD8 || m == 0x01 || (m >= 0xD0 && m <= 0xD7)) {
      p += 2;
      continue;
    }
    if (m >= 0xC0 && m <= 0xCF && m != 0xC4 && m != 0xC8 && m != 0xCC) {
      if (p + 9 >= b.length) return null;
      return ((b[p + 7] << 8) | b[p + 8], (b[p + 5] << 8) | b[p + 6], b[p + 9]);
    }
    if (m == 0xD9 || m == 0xDA) return null;
    p += 2 + ((b[p + 2] << 8) | b[p + 3]);
  }
  return null;
}

/// CCITTFaxDecode data as one grey byte per pixel (255 for the 1 bits of
/// the filter output, 0 for the 0 bits), decoded by the TIFF reader of the
/// image package in a TIFF made around it: Group 4 (K < 0) as TIFF
/// compression 4, Group 3 one-dimensional (K = 0) as compression 2 and two-
/// dimensional (K > 0, with end-of-line codes) as compression 3. Returns
/// the samples and their row width.
(Uint8List, int) _ccitt(PdfReader doc, Uint8List data, Map<String, Object?>? p, int w, int h) {
  final k = doc._int(p?['K']) ?? 0;
  final cols = doc._int(p?['Columns']) ?? (w > 0 ? w : 1728);
  final rows = h > 0 ? h : (doc._int(p?['Rows']) ?? 0);
  if (cols <= 0 || rows <= 0 || cols.toDouble() * rows > 400e6) throw const _TooLarge();
  final blackIs1 = doc._bool(p?['BlackIs1']) ?? false;
  final byteAlign = doc._bool(p?['EncodedByteAlign']) ?? false;
  final compression = k < 0 ? 4 : (k == 0 ? 2 : 3);
  final tiff = _tiffAround(data, cols, rows, compression, (k > 0 ? 1 : 0) | (byteAlign ? 4 : 0));
  final im = img.decodeTiff(tiff);
  if (im == null) throw const FormatException('ccitt');
  // white-is-zero photometric: white pixels come out 1, black 0, as the
  // filter writes them unless BlackIs1
  final g = im.convert(format: img.Format.uint8, numChannels: 1).toUint8List();
  final out = Uint8List(cols * rows);
  final n = math.min(out.length, g.length);
  for (var i = 0; i < n; i++) {
    final white = g[i] >= 128;
    out[i] = white != blackIs1 ? 255 : 0;
  }
  if (n < out.length && !blackIs1) out.fillRange(n, out.length, 255);
  return (out, cols);
}

/// A one-strip bilevel TIFF holding fax-coded [data].
Uint8List _tiffAround(Uint8List data, int w, int h, int compression, int t4) {
  final entries = <(int, int, int)>[
    (256, 4, w),
    (257, 4, h),
    (258, 3, 1),
    (259, 3, compression),
    (262, 3, 0),
    (266, 3, 1),
    (273, 4, 0),
    (277, 3, 1),
    (278, 4, h),
    (279, 4, data.length),
    if (compression == 3) (292, 4, t4),
    if (compression == 4) (293, 4, 0),
  ];
  final start = 8 + 2 + entries.length * 12 + 4;
  final out = ByteData(start + data.length);
  const le = Endian.little;
  out.setUint16(0, 0x4949, le);
  out.setUint16(2, 42, le);
  out.setUint32(4, 8, le);
  out.setUint16(8, entries.length, le);
  var p = 10;
  for (final (tag, type, value) in entries) {
    out.setUint16(p, tag, le);
    out.setUint16(p + 2, type, le);
    out.setUint32(p + 4, 1, le);
    final v = tag == 273 ? start : value;
    if (type == 3) {
      out.setUint16(p + 8, v, le);
    } else {
      out.setUint32(p + 8, v, le);
    }
    p += 12;
  }
  out.setUint32(p, 0, le);
  final bytes = out.buffer.asUint8List();
  bytes.setRange(start, start + data.length, data);
  return bytes;
}
