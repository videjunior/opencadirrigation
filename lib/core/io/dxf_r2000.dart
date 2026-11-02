/// Writer of R2000 DXF files (AC1015) from a [CadDrawing]: the
/// complete drawing database CAD programs expect from that version (handles
/// and owners on every object, the symbol tables with their records, model
/// and paper space blocks, layouts and the named object dictionaries) and
/// native entities: LWPOLYLINE with arcs, SPLINE, HATCH, TEXT, MTEXT,
/// INSERT with ATTRIBs, DIMENSION with its anonymous block, LEADER, SOLID,
/// POINT, CIRCLE, ARC and LINE. Layers carry the colour index and the true
/// colour (code 420, read by CAD programs from R2004 on), their
/// linetype and their on/locked/plot states; $INSUNITS says metres.
///
/// Text is written in ASCII: characters outside it become `\U+XXXX`, the
/// notation of the format for files in a code page ($DWGCODEPAGE
/// ANSI_1252), so the file reads the same whatever encoding a program
/// assumes. The extended data of the drawing ([CadDrawing.xdata], the
/// hydraulic data of pipes and items) follows each entity's own groups,
/// its application registered in the APPID table.
library;

import 'dart:math' as math;

import '../model/geometry.dart';
import 'cad_drawing.dart';
import 'cad_xdata.dart' show xdataApp;

class DxfR2000Writer {
  DxfR2000Writer._(this.d);
  final CadDrawing d;

  static String write(CadDrawing d) => DxfR2000Writer._(d)._build();

  StringBuffer _b = StringBuffer();

  /// Handle of the APPID record of [xdataApp], when the drawing has extended data.
  String? _appXdata;

  /// The extended data of [e], when it has any (1001 and its groups).
  void _xdata(CadEntity e) {
    final groups = d.xdata[e];
    if (groups == null || groups.isEmpty || _appXdata == null) return;
    _p(1001, xdataApp);
    for (final (code, value) in groups) {
      switch (value) {
        case double v:
          _f(code, v);
        case int v:
          _p(code, v);
        default:
          _s(code, '$value');
      }
    }
  }

  /// Handles from 0x60 on; below are the objects of the skeleton, numbered
  /// as the usual writers number them (and as the DWG writer does): programs that
  /// create those objects themselves on import (LibreDWG) find them there.
  int _next = 0x60;
  String _h() => (_next++).toRadixString(16).toUpperCase();
  static String _hex(int h) => h.toRadixString(16).toUpperCase();

  void _p(int code, Object v) {
    _b
      ..write(code.toString().padLeft(3))
      ..write('\n')
      ..write(v)
      ..write('\n');
  }

  void _s(int code, String v) => _p(code, dxfString(v));
  void _f(int code, double v) => _p(code, dxfNumber(v));
  void _pt(int code, Pt p, [double z = 0]) {
    _f(code, p.x);
    _f(code + 10, p.y);
    _f(code + 20, z);
  }

  /// Text for a group value: ASCII, characters beyond it as `\U+XXXX` (or
  /// `?` outside the Basic Multilingual Plane), no control characters, a
  /// caret written as `^ ` (the format reads `^J` as a control character).
  static String dxfString(String s) {
    final out = StringBuffer();
    for (final r in s.runes) {
      if (r == 0x5E) {
        out.write('^ ');
      } else if (r >= 0x20 && r < 0x7F) {
        out.writeCharCode(r);
      } else if (r == 0x09 || r == 0x0A || r == 0x0D) {
        out.write(' ');
      } else if (r < 0x20 || r == 0x7F) {
        continue;
      } else if (r <= 0xFFFF) {
        out.write('\\U+${r.toRadixString(16).toUpperCase().padLeft(4, '0')}');
      } else {
        out.write('?');
      }
    }
    return out.toString();
  }

  /// MTEXT content: backslashes and braces escaped, line breaks as `\P`.
  static String mtextString(String s) => dxfString(s.replaceAll('\r\n', '\n').replaceAll('\\', '\\\\').replaceAll('{', '\\{').replaceAll('}', '\\}').replaceAll('\n', '\\P'));

  /// Plain positional notation with up to 8 decimals (0 for non-finite).
  static String dxfNumber(double v) {
    if (!v.isFinite) return '0.0';
    var s = v.abs() < 1e15 ? v.toStringAsFixed(8) : v.toStringAsExponential(12);
    if (s.contains('.') && !s.contains('e')) {
      s = s.replaceFirst(RegExp(r'0+$'), '');
      if (s.endsWith('.')) s = '${s}0';
    }
    if (s == '-0.0') s = '0.0';
    return s;
  }

  // handles of the skeleton
  static final _tBlockRecord = _hex(0x01),
      _tLayer = _hex(0x02),
      _tStyle = _hex(0x03),
      _tLtype = _hex(0x05),
      _tView = _hex(0x06),
      _tUcs = _hex(0x07),
      _tVport = _hex(0x08),
      _tAppid = _hex(0x09),
      _tDimstyle = _hex(0x0A);
  static final _root = _hex(0x0C), _groupDict = _hex(0x0D), _plotStyleDict = _hex(0x0E), _placeholder = _hex(0x0F), _layer0 = _hex(0x10), _style = _hex(0x11), _appid = _hex(0x12);
  static final _ltByBlock = _hex(0x14), _ltByLayer = _hex(0x15), _ltContinuous = _hex(0x16), _mlineDict = _hex(0x17), _mlineStd = _hex(0x18), _plotSettingsDict = _hex(0x19), _layoutDict = _hex(0x1A);
  static final _brModel = _hex(0x1F), _blkModel = _hex(0x20), _endModel = _hex(0x21), _layoutModel = _hex(0x22), _dimStandard = _hex(0x27), _vport = _hex(0x2C);
  static final _brPaper = _hex(0x55), _layoutPaper = _hex(0x56), _blkPaper = _hex(0x57), _endPaper = _hex(0x58);
  final Map<String, String> _ltypes = {}, _layers = {}, _dimstyles = {}, _br = {}, _blk = {}, _endblk = {};
  late final Bounds _ext = d.extents;

  /// Layer '0' first (the format requires it), then the others once each
  /// (table names do not tell case apart: the first spelling is kept).
  late final List<CadLayer> _layerList = () {
    final out = [d.layers.firstWhere((l) => l.name == '0', orElse: () => const CadLayer('0'))];
    final seen = {'0'};
    for (final l in d.layers) {
      if (l.name.trim().isNotEmpty && seen.add(l.name.toLowerCase())) out.add(l);
    }
    return out;
  }();

  List<CadDimStyle> get _allDimStyles => [
    CadDimStyle.standard,
    for (final s in d.dimStyles)
      if (s.name != 'Standard') s,
  ];

  String _build() {
    for (final lt in d.linetypes) {
      _ltypes[lt.name] = _h();
    }
    for (final l in _layerList) {
      _layers[l.name] = l.name == '0' ? _layer0 : _h();
    }
    for (final s in _allDimStyles) {
      _dimstyles[s.name] = s.name == 'Standard' ? _dimStandard : _h();
    }
    for (final blk in d.blocks) {
      _br[blk.name] = _h();
      _blk[blk.name] = _h();
      _endblk[blk.name] = _h();
    }
    // the application of the hydraulic data (extended data) is registered
    if (d.xdata.isNotEmpty) _appXdata = _h();
    final body = StringBuffer();
    _b = body;
    _classes();
    _tables();
    _blocks();
    _entities();
    _objects();
    _p(0, 'EOF');
    _b = StringBuffer();
    _header();
    return '$_b$body';
  }

  // ------------------------------------------------------------------ header

  void _header() {
    final ext = _ext;
    void v(String name) => _p(9, name);
    _p(0, 'SECTION');
    _p(2, 'HEADER');
    v(r'$ACADVER');
    _p(1, 'AC1015');
    v(r'$ACADMAINTVER');
    _p(70, 6);
    v(r'$DWGCODEPAGE');
    _p(3, 'ANSI_1252');
    v(r'$INSBASE');
    _pt(10, Pt.zero);
    v(r'$EXTMIN');
    _pt(10, Pt(ext.minX, ext.minY));
    v(r'$EXTMAX');
    _pt(10, Pt(ext.maxX, ext.maxY));
    v(r'$LIMMIN');
    _f(10, ext.minX);
    _f(20, ext.minY);
    v(r'$LIMMAX');
    _f(10, ext.maxX);
    _f(20, ext.maxY);
    v(r'$LTSCALE');
    _f(40, 1);
    v(r'$TEXTSIZE');
    _f(40, 1);
    v(r'$TEXTSTYLE');
    _p(7, 'Standard');
    v(r'$CLAYER');
    _p(8, '0');
    v(r'$CELTYPE');
    _p(6, 'ByLayer');
    v(r'$CECOLOR');
    _p(62, 256);
    v(r'$DIMSTYLE');
    _p(2, 'Standard');
    v(r'$DIMTXSTY');
    _p(7, 'Standard');
    v(r'$LUNITS');
    _p(70, 2);
    v(r'$LUPREC');
    _p(70, 3);
    v(r'$AUNITS');
    _p(70, 0);
    v(r'$AUPREC');
    _p(70, 1);
    v(r'$PDMODE');
    _p(70, d.pointMode);
    v(r'$PDSIZE');
    _f(40, d.pointSize);
    v(r'$PLINEGEN');
    _p(70, 1);
    v(r'$HANDSEED');
    _p(5, _h());
    v(r'$CMLSTYLE');
    _p(2, 'Standard');
    v(r'$MEASUREMENT');
    _p(70, 1);
    v(r'$INSUNITS');
    _p(70, 6);
    v(r'$PSTYLEMODE');
    _p(290, 1);
    v(r'$EXTNAMES');
    _p(290, 1);
    _p(0, 'ENDSEC');
  }

  // ------------------------------------------------------------------ classes

  void _classes() {
    _p(0, 'SECTION');
    _p(2, 'CLASSES');
    for (final (dxf, cpp) in const [('ACDBDICTIONARYWDFLT', 'AcDbDictionaryWithDefault'), ('ACDBPLACEHOLDER', 'AcDbPlaceHolder'), ('LAYOUT', 'AcDbLayout')]) {
      _p(0, 'CLASS');
      _p(1, dxf);
      _p(2, cpp);
      _p(3, 'ObjectDBX Classes');
      _p(90, 0);
      _p(280, 0);
      _p(281, 0);
    }
    _p(0, 'ENDSEC');
  }

  // ------------------------------------------------------------------ tables

  void _table(String name, String handle, int count, void Function() records, {bool dimstyle = false}) {
    _p(0, 'TABLE');
    _p(2, name);
    _p(5, handle);
    _p(330, 0);
    _p(100, 'AcDbSymbolTable');
    _p(70, count);
    if (dimstyle) _p(100, 'AcDbDimStyleTable');
    records();
    _p(0, 'ENDTAB');
  }

  void _record(String type, String handle, String table, String subclass, String name, {int flags = 0, bool dimstyle = false}) {
    _p(0, type);
    _p(dimstyle ? 105 : 5, handle);
    _p(330, table);
    _p(100, 'AcDbSymbolTableRecord');
    _p(100, subclass);
    _s(2, name);
    _p(70, flags);
  }

  void _tables() {
    _p(0, 'SECTION');
    _p(2, 'TABLES');
    final ext = _ext;
    _table('VPORT', _tVport, 1, () {
      _record('VPORT', _vport, _tVport, 'AcDbViewportTableRecord', '*Active');
      _f(10, 0);
      _f(20, 0);
      _f(11, 1);
      _f(21, 1);
      _f(12, ext.center.x);
      _f(22, ext.center.y);
      _f(13, 0);
      _f(23, 0);
      _f(14, 1);
      _f(24, 1);
      _f(15, 10);
      _f(25, 10);
      _f(16, 0);
      _f(26, 0);
      _f(36, 1);
      _f(17, 0);
      _f(27, 0);
      _f(37, 0);
      _f(40, math.max(math.max(ext.height, ext.width / 1.6), 1) * 1.1);
      _f(41, 1.6);
      _f(42, 50);
      _f(43, 0);
      _f(44, 0);
      _f(50, 0);
      _f(51, 0);
      _p(71, 0);
      _p(72, 1000);
      _p(73, 1);
      _p(74, 3);
      _p(75, 0);
      _p(76, 0);
      _p(77, 0);
      _p(78, 0);
      _p(281, 0);
      _p(65, 1);
      _f(146, 0);
    });
    _table('LTYPE', _tLtype, 3 + d.linetypes.length, () {
      const none = <double>[];
      for (final (h, name, desc, dashes) in [
        (_ltByBlock, 'ByBlock', '', none),
        (_ltByLayer, 'ByLayer', '', none),
        (_ltContinuous, 'Continuous', 'Solid line', none),
        for (final lt in d.linetypes) (_ltypes[lt.name]!, lt.name, lt.description, lt.dashes),
      ]) {
        _record('LTYPE', h, _tLtype, 'AcDbLinetypeTableRecord', name);
        _s(3, desc);
        _p(72, 65);
        _p(73, dashes.length);
        _f(40, dashes.fold(0.0, (s, x) => s + x.abs()));
        for (final x in dashes) {
          _f(49, x);
          _p(74, 0);
        }
      }
    });
    _table('LAYER', _tLayer, _layerList.length, () {
      for (final l in _layerList) {
        _record('LAYER', _layers[l.name]!, _tLayer, 'AcDbLayerTableRecord', l.name, flags: l.locked ? 4 : 0);
        _p(62, l.off ? -l.aci : l.aci);
        if (l.rgb != null) _p(420, l.rgb!);
        _s(6, l.linetype);
        if (!l.plot) _p(290, 0);
        _p(370, -3);
        _p(390, _placeholder);
      }
    });
    _table('STYLE', _tStyle, 1, () {
      _record('STYLE', _style, _tStyle, 'AcDbTextStyleTableRecord', 'Standard');
      _f(40, 0);
      _f(41, 1);
      _f(50, 0);
      _p(71, 0);
      _f(42, 1);
      _s(3, d.textFont);
      _p(4, '');
    });
    _table('VIEW', _tView, 0, () {});
    _table('UCS', _tUcs, 0, () {});
    final app = _appXdata;
    _table('APPID', _tAppid, app == null ? 1 : 2, () {
      _record('APPID', _appid, _tAppid, 'AcDbRegAppTableRecord', 'ACAD');
      if (app != null) _record('APPID', app, _tAppid, 'AcDbRegAppTableRecord', xdataApp);
    });
    final styles = _allDimStyles;
    _table('DIMSTYLE', _tDimstyle, styles.length, () {
      for (final s in styles) {
        _record('DIMSTYLE', _dimstyles[s.name]!, _tDimstyle, 'AcDbDimStyleTableRecord', s.name, dimstyle: true);
        _dimStyle(s);
      }
    }, dimstyle: true);
    _table('BLOCK_RECORD', _tBlockRecord, 2 + d.blocks.length, () {
      for (final (h, name, layout) in [(_brModel, '*Model_Space', _layoutModel), (_brPaper, '*Paper_Space', _layoutPaper), for (final blk in d.blocks) (_br[blk.name]!, blk.name, '0')]) {
        _p(0, 'BLOCK_RECORD');
        _p(5, h);
        _p(330, _tBlockRecord);
        _p(100, 'AcDbSymbolTableRecord');
        _p(100, 'AcDbBlockTableRecord');
        _s(2, name);
        _p(340, layout);
      }
    });
    _p(0, 'ENDSEC');
  }

  /// The variables of a dimension style, in the order real-world files have them.
  void _dimStyle(CadDimStyle s) {
    _s(3, s.suffix);
    _p(4, '');
    _f(40, s.scale);
    _f(41, s.arrowSize);
    _f(42, s.extOffset);
    _f(43, 3.75);
    _f(44, s.extBeyond);
    _f(45, 0);
    _f(46, 0);
    _f(47, 0);
    _f(48, 0);
    _f(140, s.textHeight);
    _f(141, s.centerMark);
    _f(142, 0);
    _f(143, 0.0393700787);
    _f(144, s.lengthFactor);
    _f(145, 0);
    _f(146, 1);
    _f(147, s.gap);
    _f(148, 0);
    _p(71, 0);
    _p(72, 0);
    _p(73, s.horizontalText ? 1 : 0);
    _p(74, s.horizontalText ? 1 : 0);
    _p(75, 0);
    _p(76, 0);
    _p(77, 1);
    _p(78, s.suppressZeros);
    _p(79, 0);
    _p(170, 0);
    _p(171, 3);
    _p(172, 1);
    _p(173, 0);
    _p(174, 0);
    _p(175, 0);
    _p(176, 0);
    _p(177, 0);
    _p(178, 0);
    _p(179, s.angleDecimals);
    _p(271, s.decimals);
    _p(272, s.decimals);
    _p(273, 2);
    _p(274, 3);
    _p(275, 0);
    _p(276, 0);
    _p(277, 2);
    _p(278, 46);
    _p(279, 0);
    _p(280, 0);
    _p(281, 0);
    _p(282, 0);
    _p(283, 0);
    _p(284, 8);
    _p(285, 0);
    _p(286, 0);
    _p(288, 0);
    _p(289, 3);
    _p(340, _style);
    _p(371, -2);
    _p(372, -2);
  }

  // ------------------------------------------------------------------ blocks

  void _blockBegin(String handle, String owner, String name, {int flags = 0, Pt base = Pt.zero, bool paper = false}) {
    _p(0, 'BLOCK');
    _p(5, handle);
    _p(330, owner);
    _p(100, 'AcDbEntity');
    if (paper) _p(67, 1);
    _p(8, '0');
    _p(100, 'AcDbBlockBegin');
    _s(2, name);
    _p(70, flags);
    _pt(10, base);
    _s(3, name);
    _p(1, '');
  }

  void _blockEnd(String handle, String owner, {bool paper = false}) {
    _p(0, 'ENDBLK');
    _p(5, handle);
    _p(330, owner);
    _p(100, 'AcDbEntity');
    if (paper) _p(67, 1);
    _p(8, '0');
    _p(100, 'AcDbBlockEnd');
  }

  void _blocks() {
    _p(0, 'SECTION');
    _p(2, 'BLOCKS');
    _blockBegin(_blkModel, _brModel, '*Model_Space');
    _blockEnd(_endModel, _brModel);
    _blockBegin(_blkPaper, _brPaper, '*Paper_Space', paper: true);
    _blockEnd(_endPaper, _brPaper, paper: true);
    for (final blk in d.blocks) {
      final owner = _br[blk.name]!;
      _blockBegin(_blk[blk.name]!, owner, blk.name, flags: (blk.anonymous ? 1 : 0) | (blk.attdefs.isNotEmpty ? 2 : 0), base: blk.base);
      for (final e in blk.entities) {
        _entity(e, owner);
      }
      for (final a in blk.attdefs) {
        _attribute(a, owner, '0', definition: true);
      }
      _blockEnd(_endblk[blk.name]!, owner);
    }
    _p(0, 'ENDSEC');
  }

  // ------------------------------------------------------------------ entities

  void _entities() {
    _p(0, 'SECTION');
    _p(2, 'ENTITIES');
    for (final e in d.entities) {
      _entity(e, _brModel);
    }
    _p(0, 'ENDSEC');
  }

  /// Entity header up to the first subclass marker; returns the handle.
  String _head(String type, CadEntity e, String owner, String subclass) {
    final h = _h();
    _p(0, type);
    _p(5, h);
    _p(330, owner);
    _p(100, 'AcDbEntity');
    _s(8, e.layer);
    if (e.color != 256) _p(62, e.color);
    _p(100, subclass);
    return h;
  }

  void _entity(CadEntity e, String owner) {
    switch (e) {
      case CadLine l:
        _head('LINE', e, owner, 'AcDbLine');
        _pt(10, l.a, l.z);
        _pt(11, l.b, l.z);
        _xdata(e);
      case CadPolyline p:
        if (p.points.length < 2) return;
        _head('LWPOLYLINE', e, owner, 'AcDbPolyline');
        _p(90, p.points.length);
        _p(70, (p.closed ? 1 : 0) | 128);
        _f(43, p.width);
        if (p.elevation != 0) _f(38, p.elevation);
        for (var i = 0; i < p.points.length; i++) {
          _f(10, p.points[i].x);
          _f(20, p.points[i].y);
          if (p.bulgeAt(i) != 0) _f(42, p.bulgeAt(i));
        }
        _xdata(e);
      case CadCircle c:
        _head('CIRCLE', e, owner, 'AcDbCircle');
        _pt(10, c.center);
        _f(40, c.radius);
      case CadArc a:
        _head('ARC', e, owner, 'AcDbCircle');
        _pt(10, a.center);
        _f(40, a.radius);
        _p(100, 'AcDbArc');
        _f(50, a.startDeg);
        _f(51, a.endDeg);
      case CadPoint p:
        _head('POINT', e, owner, 'AcDbPoint');
        _pt(10, p.position, p.z);
      case CadText t:
        if (t.text.trim().isEmpty) return;
        _head('TEXT', e, owner, 'AcDbText');
        _pt(10, t.position, t.z);
        _f(40, t.height);
        _s(1, t.text.length > 250 ? t.text.substring(0, 250) : t.text);
        if (t.rotationDeg != 0) _f(50, t.rotationDeg);
        _p(7, 'Standard');
        if (t.hAlign != 0) _p(72, t.hAlign);
        if (t.aligned) _pt(11, t.position, t.z);
        _p(100, 'AcDbText');
        if (t.vAlign != 0) _p(73, t.vAlign);
        // the label of a hydraulic item says whose it is
        _xdata(e);
      case CadMText m:
        if (m.text.trim().isEmpty) return;
        _head('MTEXT', e, owner, 'AcDbMText');
        _pt(10, m.position);
        _f(40, m.height);
        _f(41, m.width);
        _p(71, m.attachment);
        _p(72, 1);
        // long text comes in chunks of 250 characters, the last one on code 1
        // (readers join them before interpreting the escapes)
        final s = mtextString(m.text);
        var k = 0;
        for (; s.length - k > 250; k += 250) {
          _p(3, s.substring(k, k + 250));
        }
        _p(1, s.substring(k));
        _p(7, 'Standard');
        if (m.rotationDeg != 0) {
          final r = degToRad(m.rotationDeg);
          _pt(11, Pt(math.cos(r), math.sin(r)));
        }
      case CadSpline s:
        if (s.control.length < s.degree + 1) return;
        _head('SPLINE', e, owner, 'AcDbSpline');
        _pt(210, Pt.zero, 1);
        _p(70, 8 | (s.closed ? 1 : 0));
        _p(71, s.degree);
        _p(72, s.knots.length);
        _p(73, s.control.length);
        _p(74, s.fit.length);
        _f(42, 1e-10);
        _f(43, 1e-10);
        if (s.fit.isNotEmpty) _f(44, 1e-10);
        if (s.fit.isNotEmpty && s.startTangent != null) _pt(12, s.startTangent!);
        if (s.fit.isNotEmpty && s.endTangent != null) _pt(13, s.endTangent!);
        for (final k in s.knots) {
          _f(40, k);
        }
        for (final c in s.control) {
          _pt(10, c);
        }
        for (final f in s.fit) {
          _pt(11, f);
        }
      case CadHatch h:
        final loops = h.loops.where((l) => l.points.length >= 2).toList();
        if (loops.isEmpty) return;
        _head('HATCH', e, owner, 'AcDbHatch');
        _pt(10, Pt.zero);
        _pt(210, Pt.zero, 1);
        _p(2, h.solid ? 'SOLID' : h.pattern);
        _p(70, h.solid ? 1 : 0);
        _p(71, 0);
        _p(91, loops.length);
        for (var i = 0; i < loops.length; i++) {
          final l = loops[i];
          // outer loop external, islands plain; both polyline paths
          _p(92, i == 0 ? 3 : 2);
          _p(72, l.hasBulges ? 1 : 0);
          _p(73, 1);
          _p(93, l.points.length);
          for (var k = 0; k < l.points.length; k++) {
            _f(10, l.points[k].x);
            _f(20, l.points[k].y);
            if (l.hasBulges) _f(42, l.bulgeAt(k));
          }
          _p(97, 0);
        }
        _p(75, 0);
        _p(76, 1);
        if (!h.solid) {
          _f(52, h.patternAngleDeg);
          _f(41, h.patternScale);
          _p(77, 0);
          _p(78, h.lines.length);
          for (final pl in h.lines) {
            _f(53, pl.angleDeg);
            _f(43, pl.base.x);
            _f(44, pl.base.y);
            _f(45, pl.offset.x);
            _f(46, pl.offset.y);
            _p(79, pl.dashes.length);
            for (final dash in pl.dashes) {
              _f(49, dash);
            }
          }
        }
        _p(98, 0);
      case CadSolid s:
        _head('SOLID', e, owner, 'AcDbTrace');
        _pt(10, s.p1);
        _pt(11, s.p2);
        _pt(12, s.p3);
        _pt(13, s.p4);
      case CadInsert ins:
        final h = _head('INSERT', e, owner, 'AcDbBlockReference');
        if (ins.attribs.isNotEmpty) _p(66, 1);
        _s(2, ins.block);
        _pt(10, ins.position);
        if (ins.scale != 1) {
          _f(41, ins.scale);
          _f(42, ins.scale);
          _f(43, ins.scale);
        }
        if (ins.rotationDeg != 0) _f(50, ins.rotationDeg);
        _xdata(e);
        if (ins.attribs.isEmpty) return;
        for (final a in ins.attribs) {
          _attribute(a, h, e.layer, color: e.color);
        }
        _p(0, 'SEQEND');
        _p(5, _h());
        _p(330, h);
        _p(100, 'AcDbEntity');
        _s(8, e.layer);
      case CadDimension dm:
        _head('DIMENSION', e, owner, 'AcDbDimension');
        _s(2, dm.block);
        _pt(10, dm.defPoint);
        _pt(11, dm.textMid);
        _p(70, dm.dxfFlags);
        _p(71, 5);
        _f(42, dm.measurement);
        if (dm.text.isNotEmpty) _s(1, dm.text);
        _s(3, dm.style);
        switch (dm.kind) {
          case CadDimKind.aligned:
            _p(100, 'AcDbAlignedDimension');
            _pt(13, dm.p13);
            _pt(14, dm.p14);
          case CadDimKind.angular:
            _p(100, 'AcDb3PointAngularDimension');
            _pt(13, dm.p13);
            _pt(14, dm.p14);
            _pt(15, dm.p15);
          case CadDimKind.radius:
            _p(100, 'AcDbRadialDimension');
            _pt(15, dm.p15);
            _f(40, 0);
          case CadDimKind.diameter:
            _p(100, 'AcDbDiametricDimension');
            _pt(15, dm.p15);
            _f(40, 0);
          case CadDimKind.ordinate:
            _p(100, 'AcDbOrdinateDimension');
            _pt(13, dm.p13);
            _pt(14, dm.p14);
        }
      case CadLeader l:
        if (l.points.length < 2) return;
        _head('LEADER', e, owner, 'AcDbLeader');
        _s(3, l.style);
        _p(71, l.arrow ? 1 : 0);
        _p(72, 0);
        _p(73, 3);
        _p(74, 0);
        _p(75, 0);
        _f(40, 0);
        _f(41, 0);
        _p(76, l.points.length);
        for (final p in l.points) {
          _pt(10, p);
        }
    }
  }

  /// ATTRIB of a block reference (owned by it) or ATTDEF of a block.
  void _attribute(CadAttrib a, String owner, String layer, {bool definition = false, int color = 256}) {
    _p(0, definition ? 'ATTDEF' : 'ATTRIB');
    _p(5, _h());
    _p(330, owner);
    _p(100, 'AcDbEntity');
    _s(8, layer);
    if (color != 256) _p(62, color);
    _p(100, 'AcDbText');
    _pt(10, a.position);
    _f(40, a.height);
    _s(1, a.value);
    if (a.rotationDeg != 0) _f(50, a.rotationDeg);
    _p(7, 'Standard');
    if (definition) {
      _p(100, 'AcDbAttributeDefinition');
      _s(3, a.prompt);
    } else {
      _p(100, 'AcDbAttribute');
    }
    _s(2, a.tag);
    _p(70, a.invisible ? 1 : 0);
  }

  // ------------------------------------------------------------------ objects

  void _dict(String type, String handle, String owner, List<(String, String)> items, {String? defaultId}) {
    _p(0, type);
    _p(5, handle);
    _p(330, owner);
    _p(100, 'AcDbDictionary');
    _p(281, 1);
    for (final (name, h) in items) {
      _p(3, name);
      _p(350, h);
    }
    if (defaultId != null) {
      _p(100, 'AcDbDictionaryWithDefault');
      _p(340, defaultId);
    }
  }

  void _objects() {
    _p(0, 'SECTION');
    _p(2, 'OBJECTS');
    _dict('DICTIONARY', _root, '0', [
      ('ACAD_GROUP', _groupDict),
      ('ACAD_LAYOUT', _layoutDict),
      ('ACAD_MLINESTYLE', _mlineDict),
      ('ACAD_PLOTSETTINGS', _plotSettingsDict),
      ('ACAD_PLOTSTYLENAME', _plotStyleDict),
    ]);
    _dict('DICTIONARY', _groupDict, _root, const []);
    _dict('DICTIONARY', _layoutDict, _root, [('Layout1', _layoutPaper), ('Model', _layoutModel)]);
    _dict('DICTIONARY', _mlineDict, _root, [('Standard', _mlineStd)]);
    _dict('DICTIONARY', _plotSettingsDict, _root, const []);
    _dict('ACDBDICTIONARYWDFLT', _plotStyleDict, _root, [('Normal', _placeholder)], defaultId: _placeholder);
    _p(0, 'ACDBPLACEHOLDER');
    _p(5, _placeholder);
    _p(330, _plotStyleDict);
    _p(0, 'MLINESTYLE');
    _p(5, _mlineStd);
    _p(330, _mlineDict);
    _p(100, 'AcDbMlineStyle');
    _p(2, 'Standard');
    _p(70, 0);
    _p(3, '');
    _p(62, 256);
    _f(51, 90);
    _f(52, 90);
    _p(71, 2);
    for (final off in const [0.5, -0.5]) {
      _f(49, off);
      _p(62, 256);
      _p(6, 'BYLAYER');
    }
    final ext = _ext;
    _layout(_layoutModel, 'Model', 0, _brModel, ext, model: true);
    _layout(_layoutPaper, 'Layout1', 1, _brPaper, ext, model: false);
    _p(0, 'ENDSEC');
  }

  void _layout(String handle, String name, int tab, String blockRecord, Bounds ext, {required bool model}) {
    _p(0, 'LAYOUT');
    _p(5, handle);
    _p(330, _layoutDict);
    _p(100, 'AcDbPlotSettings');
    _p(1, '');
    _p(4, 'ISO_A3_(420.00_x_297.00_MM)');
    _p(6, '');
    _f(40, 7.5);
    _f(41, 20);
    _f(42, 7.5);
    _f(43, 20);
    _f(44, 420);
    _f(45, 297);
    _f(46, 0);
    _f(47, 0);
    _f(48, 0);
    _f(49, 0);
    _f(140, 0);
    _f(141, 0);
    _f(142, 1);
    _f(143, 1);
    _p(70, model ? 1024 : 0);
    _p(72, 1);
    _p(73, 0);
    _p(74, 5);
    _p(7, '');
    _p(75, 16);
    _f(147, 1);
    _f(148, 0);
    _f(149, 0);
    _p(100, 'AcDbLayout');
    _p(1, name);
    _p(70, 1);
    _p(71, tab);
    _f(10, 0);
    _f(20, 0);
    _f(11, 420);
    _f(21, 297);
    _pt(12, Pt.zero);
    if (model) {
      _pt(14, Pt(ext.minX, ext.minY));
      _pt(15, Pt(ext.maxX, ext.maxY));
    } else {
      _pt(14, const Pt(1e20, 1e20), 1e20);
      _pt(15, const Pt(-1e20, -1e20), -1e20);
    }
    _f(146, 0);
    _pt(13, Pt.zero);
    _pt(16, const Pt(1, 0));
    _pt(17, const Pt(0, 1));
    _p(76, 0);
    _p(330, blockRecord);
  }
}
