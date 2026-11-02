/// The professional title block of the drawing sheets (1.6.0 PRD, PRD-01),
/// printed when the project's title block has anything set
/// ([TitleBlock.isProfessional]): a band of cells across the bottom of the
/// sheet, each with its caption over its value (the layout of ISO 7200
/// data fields), in columns:
/// - the project: name, client, property, municipality/state;
/// - the records: CAR, water permit, stage, notes;
/// - the technical lead: name, council and registration, ART/RRT/TRT,
///   designer;
/// - the sheet: drawing number and sheet, scale and paper, date, the
///   coordinate system (datum and UTM zone, EPSG and origin);
/// - the company: its logo and name (the program's name when neither is set).
/// Optional cells that are empty are left out and the column's other cells
/// take their room; the widths follow what each column holds.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../model/entities.dart' show RevisionCloudEntity;
import '../model/project.dart';
import '../model/title_block.dart';
import '../translate.dart';
import 'fonts/pdf_fonts.dart';
import 'image_decode.dart';
import 'pdf.dart' show PdfAlign, PdfDocument, ptPerMm;
import 'sheet_canvas.dart';
import 'sheet_set.dart' show naturalCompare;

/// Height (mm) of the professional title block.
const proTitleBlockMm = 40.0;

/// Largest side (pixels) a logo is kept at; larger pictures are scaled down.
const logoMaxPx = 512;

/// Largest logo file kept as it is (bytes); a larger one is re-encoded.
const logoMaxBytes = 256 * 1024;

/// A logo for the title block from a picture file: PNG and JPEG up to
/// [logoMaxPx] pixels a side and [logoMaxBytes] are kept as they are,
/// anything else is scaled down and written as PNG (keeping transparency).
/// Returns the bytes and their media type, or null when [bytes] is no
/// picture.
(Uint8List, String)? normalizeLogo(Uint8List bytes) {
  final size = PdfDocument.pixelSize(bytes);
  final jpegInfo = PdfDocument.jpegInfo(bytes);
  // grey or RGB JPEG goes into the PDF as it is; CMYK is re-encoded
  final jpeg = jpegInfo != null && (jpegInfo.$3 == 1 || jpegInfo.$3 == 3);
  final png = jpegInfo == null && size != null;
  if ((jpeg || png) && size!.$1 > 0 && size.$2 > 0 && size.$1 <= logoMaxPx && size.$2 <= logoMaxPx && bytes.length <= logoMaxBytes) {
    // a picture the decoder refuses is no logo either
    try {
      if ((jpeg ? decodeJpgSafe(bytes) : decodePngSafe(bytes)) == null) return null;
    } on FormatException {
      return null;
    }
    return (bytes, jpeg ? 'image/jpeg' : 'image/png');
  }
  img.Image? decoded;
  try {
    decoded = decodeImageSafe(bytes);
  } on FormatException {
    return null;
  }
  if (decoded == null || decoded.width <= 0 || decoded.height <= 0) return null;
  final scale = math.min(1.0, logoMaxPx / math.max(decoded.width, decoded.height));
  final w = math.max(1, (decoded.width * scale).round()), h = math.max(1, (decoded.height * scale).round());
  final small = scale < 1 ? img.copyResize(decoded, width: w, height: h, interpolation: img.Interpolation.average) : decoded;
  return (Uint8List.fromList(img.encodePng(small)), 'image/png');
}

/// A cell of the title block: [caption] over [value], an optional smaller
/// [note] under it.
class TitleCell {
  const TitleCell(this.caption, this.value, {this.note = '', this.bold = false, this.size = 7.5});
  final String caption, value, note;
  final bool bold;
  final double size;
}

/// The text columns of the professional title block of [p] for one sheet
/// (the logo column is not among them): optional cells without a value are
/// left out, and so are columns left empty.
List<List<TitleCell>> titleBlockColumns(
  Project p,
  Translate t, {
  required String sheet,
  int number = 1,
  int count = 1,
  required String scale,
  String paper = '',
  required String date,
  String crs = '',
  String crsNote = '',
}) {
  final m = p.meta, tb = m.titleBlock;
  bool set(String s) => s.trim().isNotEmpty;
  String one(String s) => s.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();
  final rev = tb.currentRevision;
  final dn = tb.drawingNumber.trim();
  final sheetValue = dn.isEmpty ? sheet : (count > 1 ? '$dn-${number.toString().padLeft(2, '0')}' : dn);
  final sheetNote = [if (dn.isNotEmpty) sheet, if (rev.isNotEmpty) '${t('pdf.rev')} $rev'].join(' · ');
  final cols = <List<TitleCell>>[
    [
      TitleCell(t('dlg.project'), m.name.isEmpty ? t('name.newProject') : one(m.name), bold: true, size: 10),
      if (set(m.client)) TitleCell(t('dlg.client'), one(m.client)),
      if (set(m.site)) TitleCell(t('prd.tb.property'), one(m.site)),
      if (set(tb.municipality)) TitleCell(t('prd.tb.municipality'), one(tb.municipality)),
    ],
    [
      if (set(tb.car)) TitleCell(t('prd.tb.car'), one(tb.car)),
      if (set(tb.waterPermit)) TitleCell(t('prd.tb.permit'), one(tb.waterPermit)),
      if (tb.stage != ProjectStage.none) TitleCell(t('prd.tb.stage'), t('prd.stage.${tb.stage.name}')),
      if (set(m.notes)) TitleCell(t('dlg.notes'), one(m.notes)),
    ],
    [
      if (set(tb.responsible)) TitleCell(t('prd.tb.responsible'), one(tb.responsible), bold: true),
      if (set(tb.registrationText)) TitleCell(t('prd.tb.registration'), tb.registrationText),
      if (set(tb.responsibilityRecord)) TitleCell(tb.recordName, one(tb.responsibilityRecord)),
      if (set(m.designer)) TitleCell(t('dlg.designer'), one(m.designer)),
    ],
    [
      TitleCell(t('pdf.sheet'), sheetValue, bold: true, note: sheetNote),
      TitleCell(t('pdf.scale'), scale, note: paper),
      TitleCell(t('pdf.date'), date),
      TitleCell(t('pdf.crs'), crs.isEmpty ? t('pdf.local') : crs, note: crsNote),
    ],
  ];
  return [
    for (final c in cols)
      if (c.isNotEmpty) c,
  ];
}

const _ink = 0xFF1A1A1A;
const _grey = 0xFF8A8F94;
const _brand = 0xFF1E88E5;

/// Draws the professional title block of [p] in the band [x0], [y0], [w] ×
/// [h] (mm, from the bottom-left of the sheet); the cells as
/// [titleBlockColumns] lays them out, then the logo and company.
void drawProTitleBlock(
  SheetCanvas page,
  PdfFonts fonts,
  Translate t,
  Project p, {
  required double x0,
  required double y0,
  required double w,
  required double h,
  required String sheet,
  int number = 1,
  int count = 1,
  required String scale,
  String paper = '',
  required String date,
  String crs = '',
  String crsNote = '',
  required String generated,
}) {
  double px(double mm) => mm * ptPerMm;
  const pad = 1.6; // mm
  final tb = p.meta.titleBlock;
  final cols = titleBlockColumns(p, t, sheet: sheet, number: number, count: count, scale: scale, paper: paper, date: date, crs: crs, crsNote: crsNote);
  // what each text column would like (mm), then the logo column
  double want(List<TitleCell> c) {
    var m = 0.0;
    for (final cell in c) {
      m = math.max(m, fonts.textWidth(cell.caption.toUpperCase(), 5) / ptPerMm);
      m = math.max(m, fonts.textWidth(cell.value, cell.size, bold: cell.bold) / ptPerMm);
      if (cell.note.isNotEmpty) m = math.max(m, fonts.textWidth(cell.note, 5.5) / ptPerMm);
    }
    return m + 2 * pad;
  }

  final logo = tb.logo;
  final company = tb.company.trim();
  final logoWant = math.max(logo != null ? 34.0 : 0.0, company.isEmpty ? (logo == null ? 34.0 : 0.0) : fonts.textWidth(company, 8, bold: true) / ptPerMm + 2 * pad);
  final wants = [for (final c in cols) math.max(18.0, math.min(want(c), 110.0)), math.min(logoWant, 70.0)];
  final sum = wants.fold(0.0, (a, b) => a + b);
  // spare room goes to the text columns, a shortfall is taken from all
  final widths = sum <= w ? [for (var i = 0; i < wants.length; i++) i < cols.length ? wants[i] + (w - sum) * wants[i] / (sum - wants.last) : wants[i]] : [for (final x in wants) x * w / sum];
  page.strokeColor(_ink);
  page.lineWidth(px(0.25));
  page.dash(false);
  var x = x0;
  for (var c = 0; c < cols.length; c++) {
    final cw = widths[c];
    final cells = cols[c];
    final ch = h / cells.length;
    for (var r = 0; r < cells.length; r++) {
      final cell = cells[r];
      final top = y0 + h - r * ch;
      if (r > 0) {
        page.lineWidth(px(0.15));
        page.line(px(x), px(top), px(x + cw), px(top));
      }
      page.fillColor(_grey);
      page.text(px(x + pad), px(top - 2.4), fonts.fit(cell.caption.toUpperCase(), px(cw - 2 * pad), 5), size: 5);
      page.fillColor(_ink);
      final valueY = top - 2.4 - 1.2 - cell.size * 0.72 / ptPerMm - 0.6;
      page.text(px(x + pad), px(valueY), fonts.fit(cell.value, px(cw - 2 * pad), cell.size, bold: cell.bold), size: cell.size, bold: cell.bold);
      if (cell.note.isNotEmpty && valueY - 2.6 > top - ch + 0.6) {
        page.fillColor(_grey);
        page.text(px(x + pad), px(valueY - 2.6), fonts.fit(cell.note, px(cw - 2 * pad), 5.5), size: 5.5);
      }
    }
    x += cw;
    if (c < cols.length) {
      page.strokeColor(_ink);
      page.lineWidth(px(0.25));
      page.line(px(x), px(y0), px(x), px(y0 + h));
    }
  }
  // the company: logo, name, and the program's line at the bottom
  final lw = widths.last;
  final cx = x + lw / 2;
  page.fillColor(_grey);
  page.text(px(cx), px(y0 + 2.2), fonts.fit(generated, px(lw - 2 * pad), 5), size: 5, align: PdfAlign.center);
  final nameH = company.isEmpty ? 0.0 : 4.2;
  final boxTop = y0 + h - pad, boxBottom = y0 + 4.6 + nameH;
  if (logo != null && boxTop - boxBottom > 4) {
    final size = PdfDocument.pixelSize(logo);
    if (size != null && size.$1 > 0 && size.$2 > 0) {
      final bw = lw - 2 * pad, bh = boxTop - boxBottom;
      final s = math.min(bw / size.$1, bh / size.$2);
      final iw = size.$1 * s, ih = size.$2 * s;
      final ix = cx - iw / 2, iy = boxBottom + (bh - ih) / 2;
      // pixels for 300 dpi at the printed size
      final wPx = math.max(16, (iw / 25.4 * 300).ceil()), hPx = math.max(16, (ih / 25.4 * 300).ceil());
      page.image(logo, tb.logoMime, (px(ix), px(iy)), (px(ix + iw), px(iy)), (px(ix), px(iy + ih)), maxWidthPx: wPx, maxHeightPx: hPx);
    }
  }
  if (company.isNotEmpty) {
    page.fillColor(_ink);
    final size = logo == null ? 10.0 : 8.0;
    page.text(px(cx), px(logo == null ? y0 + h / 2 - 1.2 : y0 + 5.2), fonts.fit(company, px(lw - 2 * pad), size, bold: true), size: size, bold: true, align: PdfAlign.center);
  } else if (logo == null) {
    page.fillColor(_brand);
    page.text(px(cx), px(y0 + h / 2), fonts.fit('OpenCADIrrigation', px(lw - 2 * pad), 10, bold: true), size: 10, bold: true, align: PdfAlign.center);
    page.fillColor(_grey);
    page.text(px(cx), px(y0 + h / 2 - 4.5), fonts.fit(t('pdf.subtitle'), px(lw - 2 * pad), 5.5), size: 5.5, align: PdfAlign.center);
  }
}

/// A row of the revision table of the sheets.
class SheetRevision {
  const SheetRevision(this.revision, this.date, this.description, [this.author = '']);
  final String revision, date, description, author;
}

/// The revision table of [p]'s sheets: the revisions typed in the title
/// block, then those of the revision clouds, one row per distinct revision,
/// date and description, in the natural order of the revisions (by date
/// within one revision).
List<SheetRevision> sheetRevisions(Project p) {
  final seen = <String>{};
  final out = <SheetRevision>[];
  void add(String rev, String date, String desc, [String by = '']) {
    final r = rev.trim(), d = date.trim(), x = desc.trim();
    if (r.isEmpty && x.isEmpty) return;
    if (seen.add('$r|$d|$x')) out.add(SheetRevision(r, d, x, by.trim()));
  }

  for (final r in p.meta.titleBlock.revisions) {
    add(r.revision, r.date, r.description, r.author);
  }
  for (final r in p.entities.whereType<RevisionCloudEntity>()) {
    add(r.revision, r.date, r.description);
  }
  out.sort((a, b) => a.revision == b.revision ? a.date.compareTo(b.date) : naturalCompare(a.revision, b.revision));
  return out;
}
