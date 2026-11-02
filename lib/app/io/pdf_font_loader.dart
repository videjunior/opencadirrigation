/// Fonts for the PDF exports: before a PDF is written, the bundled Noto
/// fonts its texts need beyond Helvetica (the interface language, names and
/// notes typed in the project, report cells) are loaded from the assets into
/// [PdfFonts.shared], once per session and only the scripts in use.
library;

import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import '../../core/io/fonts/pdf_fonts.dart';

/// Reads a bundled font file (tests swap it).
Future<Uint8List> Function(String asset) pdfFontLoader = (asset) async => (await rootBundle.load(asset)).buffer.asUint8List();

/// Registers the bundled Latin font in [PdfFonts.shared] (a PDF/A document
/// draws with it the text Helvetica would draw: every font embedded).
/// False when it cannot be loaded (the document then keeps Helvetica).
Future<bool> ensurePdfLatinFont() async {
  final fonts = PdfFonts.shared;
  if (fonts.isRegistered(BundledFonts.latin)) return true;
  try {
    return fonts.register(BundledFonts.latin, await pdfFontLoader(BundledFonts.asset(BundledFonts.latin)));
  } catch (_) {
    return false;
  }
}

/// Registers in [PdfFonts.shared] every bundled font [texts] need, for
/// [language] (the interface language: Japanese and Marathi forms); a font
/// that fails to load leaves its text to the next font of the chain.
Future<void> preparePdfFonts(Iterable<String> texts, {String? language}) async {
  final fonts = PdfFonts.shared..language = language;
  final list = [
    for (final t in texts)
      if (t.isNotEmpty) t,
  ];
  // a second round adds the fallbacks of characters the first fonts lack
  for (var round = 0; round < 3; round++) {
    final missing = fonts.missingFor(list);
    if (missing.isEmpty) return;
    var loaded = false;
    for (final name in missing) {
      try {
        if (fonts.register(name, await pdfFontLoader(BundledFonts.asset(name)))) loaded = true;
      } catch (_) {
        // offline or missing asset: the text degrades as without the font
      }
    }
    if (!loaded) return;
  }
}
