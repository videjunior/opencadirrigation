/// Reads the string table of a language from the app assets
/// (`assets/i18n/<code>.json`), for [ensureLanguageLoaded]. On the web the
/// file is fetched only when that language is chosen, so the other
/// languages cost nothing to visitors who never use them.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/painting.dart' show PaintingBinding;
import 'package:flutter/services.dart' show rootBundle;

import 'i18n.dart';

/// Installs the asset reader as the [languageLoader]. Call once before
/// `runApp`, then `await ensureLanguageLoaded(...)` for the start language.
void useAssetLanguageLoader() => languageLoader = loadLanguageAsset;

Future<Map<String, dynamic>> loadLanguageAsset(String code) async {
  final text = await rootBundle.loadString('assets/i18n/$code.json');
  return jsonDecode(text) as Map<String, dynamic>;
}

/// Languages whose script is not in the bundled Roboto (Latin, Cyrillic,
/// Greek): on the web their glyphs come from fallback fonts that the engine
/// fetches the first time it lays out such text.
const fallbackFontLanguages = {'zh', 'ja', 'ar', 'ur', 'hi', 'mr', 'bn', 'pa', 'te'};

/// Fetches the fallback fonts of [lang] before the first frame.
///
/// On the web the engine lays out text with placeholder glyphs while the
/// fallback font downloads, and widgets measured that way (menu bar buttons,
/// table columns) keep their narrower size after the real glyphs arrive, so
/// labels wrap. Laying out the whole pack once here triggers the download of
/// every glyph subset the language needs; the engine reports the new fonts
/// through [PaintingBinding.systemFonts], possibly in several batches (one per
/// font family), so the wait ends [settle] after the last report, and at most
/// [timeout] after the start (a slow network only means the first layout is
/// measured with placeholder glyphs, as before). No-op off the web, for the
/// bundled languages and when the pack is not loaded.
Future<void> warmUpFonts(String lang, {Duration timeout = const Duration(seconds: 3), Duration settle = const Duration(milliseconds: 250)}) async {
  if (!kIsWeb || !fallbackFontLanguages.contains(lang)) return;
  final pack = languagePack(lang);
  if (pack == null) return;
  final sample = [...pack.strings.values, ...pack.tutorial.values, ...pack.catalog.values].join(' ');
  final done = Completer<void>();
  Timer? settling;
  void onFonts() {
    settling?.cancel();
    settling = Timer(settle, () {
      if (!done.isCompleted) done.complete();
    });
  }
  final fonts = PaintingBinding.instance.systemFonts;
  fonts.addListener(onFonts);
  try {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle())..addText(sample);
    builder.build().layout(const ui.ParagraphConstraints(width: 1e6));
    await done.future.timeout(timeout, onTimeout: () {});
  } catch (_) {
    // Font warm-up is best effort.
  } finally {
    settling?.cancel();
    fonts.removeListener(onFonts);
  }
}
