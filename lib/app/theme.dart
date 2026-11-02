/// Colours of the interface: the dark theme (the default) and the light one,
/// chosen under View → Theme and switched live.
///
/// Widgets read the colours through [Cad] (static getters over the current
/// [CadPalette]); [CadThemeHost] picks the palette and, when it changes,
/// rebuilds and repaints the whole tree, so no widget has to depend on the
/// [Theme] for its colours. Plots and exports (PDF, SVG, PNG sheets, DXF…)
/// are paper and never follow the interface theme.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'io/prefs.dart';
import 'ui_prefs.dart' show uiHighContrast; // 1.6.0 UI

/// Every colour token of the interface in one brightness. [dark] is the
/// original look of the app; [light] is designed for WCAG AA contrast of the
/// text on its surfaces.
@immutable
class CadPalette {
  const CadPalette({
    required this.brightness,
    required this.canvas,
    required this.gridMinor,
    required this.gridMajor,
    required this.axis,
    required this.gridLabel,
    required this.canvasText,
    required this.crosshair,
    required this.selection,
    required this.hover,
    required this.snap,
    required this.preview,
    required this.unconnected,
    required this.profilePath,
    required this.gps,
    required this.gpsTrack,
    required this.stakeOut,
    required this.wireOk,
    required this.commentText,
    required this.background,
    required this.panel,
    required this.panelAlt,
    required this.menu,
    required this.dialog,
    required this.card,
    required this.cardHigh,
    required this.raised,
    required this.raisedTranslucent,
    required this.inset,
    required this.insetDeep,
    required this.overlay,
    required this.overlayStrong,
    required this.overlayFaint,
    required this.stripe,
    required this.divider,
    required this.scrim,
    required this.bubble,
    required this.tintInfo,
    required this.tintWarning,
    required this.fg,
    required this.fg87,
    required this.fg70,
    required this.fg60,
    required this.fg54,
    required this.fg38,
    required this.fg30,
    required this.fg24,
    required this.fg12,
    required this.fg10,
    required this.bodyText,
    required this.accent,
    required this.accentFill,
    required this.accentText,
    required this.accentIcon,
    required this.info,
    required this.infoFill,
    required this.codeText,
    required this.ok,
    required this.okAlt,
    required this.okFill,
    required this.positive,
    required this.warning,
    required this.caution,
    required this.attention,
    required this.amber,
    required this.highlight,
    required this.error,
    required this.chartGrid,
    required this.chartGround,
    required this.chartGroundDark,
    required this.chartPipe,
    required this.chartHgl,
    required this.chartLow,
    required this.chartHigh,
    required this.chartMax,
    required this.chartRating,
    required this.chartVapour,
  });

  final Brightness brightness;

  // ---- canvas (the CAD view)
  /// Background of the drawing.
  final Color canvas;
  final Color gridMinor, gridMajor, axis;

  /// Coordinates written along the major grid lines.
  final Color gridLabel;

  /// Default colour of the labels the canvas writes (areas, results…).
  final Color canvasText;

  /// Cursor cross-hair of the drawing tools.
  final Color crosshair;
  final Color selection, hover, snap;

  /// Rubber-band previews of the tools.
  final Color preview;

  /// Unconnected items, low-pressure markers out of the window, errors.
  final Color unconnected;

  /// The terrain profile path drawn on the plan.
  final Color profilePath;

  /// Device position (dot and accuracy circle), the walk being recorded and
  /// the stake-out line to the selected item.
  final Color gps, gpsTrack, stakeOut;

  /// Valve wiring label when the solenoid voltage is fine.
  final Color wireOk;

  /// Text of a review comment shown on hover.
  final Color commentText;

  // ---- surfaces
  /// Behind everything (window, reports panel).
  final Color background;

  /// Menu bar, palettes, side panels, status bar, sheets.
  final Color panel;

  /// Strip a shade apart from the panels (the project tab bar).
  final Color panelAlt;

  /// Menu bar.
  final Color menu;
  final Color dialog;

  /// Cards inside dialogs (welcome gallery, version box).
  final Color card;

  /// A card a step above [card] (the AI key box).
  final Color cardHigh;

  /// Floating cards over the workspace (tutorial) and their translucent
  /// variant (the design progress card).
  final Color raised, raisedTranslucent;

  /// Small drawing previews inside dialogs ([insetDeep]: under pictures).
  final Color inset, insetDeep;

  /// Translucent buttons and chips over the canvas: normal, strong (also
  /// the label boxes of the charts) and disabled.
  final Color overlay, overlayStrong, overlayFaint;

  /// Every other row of a table.
  final Color stripe;
  final Color divider;

  /// Dims the interface around the tutorial spotlight.
  final Color scrim;

  /// The user's messages in the AI assistant.
  final Color bubble;

  /// Tinted boxes: information (changes made) and warning (asks for
  /// permission).
  final Color tintInfo, tintWarning;

  // ---- text and icons on the surfaces: the steps of white on the dark theme
  final Color fg, fg87, fg70, fg60, fg54, fg38, fg30, fg24, fg12, fg10;

  /// Body text of the tutorial.
  final Color bodyText;

  // ---- accents
  /// Indicators (selected tab, current layer, spotlight), links, badges.
  final Color accent;

  /// Fill of a selected tool (with a white icon on it).
  final Color accentFill;

  /// Text and icons in the accent colour: typed commands, shortcuts, version.
  final Color accentText, accentIcon;

  /// Information text and fills (GPS chip).
  final Color info, infoFill;

  /// Monospace values the AI assistant sends to the tools.
  final Color codeText;
  final Color ok;

  /// A value within its limit in the calculators.
  final Color okAlt;

  /// Fill of a confirming button (with a white icon on it).
  final Color okFill;

  /// Totals and the best values of a comparison.
  final Color positive;

  /// Warnings: [warning] (results, checks), [caution] and [attention]
  /// (notes and errors of the dialogs).
  final Color warning, caution, attention;

  /// Unsaved changes, locked layers and items.
  final Color amber;

  /// The design running on its own.
  final Color highlight;
  final Color error;

  // ---- charts (profile, hydraulic grade line, transients, plan previews)
  final Color chartGrid, chartGround, chartGroundDark, chartPipe, chartHgl, chartLow, chartHigh, chartMax, chartRating, chartVapour;

  /// The palette of [b].
  /// The palette of [b]: the high-contrast one while View → Interface →
  /// High contrast is on (1.6.0 UI).
  static CadPalette of(Brightness b) => uiHighContrast.value ? (b == Brightness.light ? lightHigh : darkHigh) : (b == Brightness.light ? light : dark);

  /// This palette with the colours given changed (1.6.0 UI: the high-contrast palettes).
  CadPalette copyWith({
    Color? canvas,
    Color? gridMinor,
    Color? gridMajor,
    Color? axis,
    Color? gridLabel,
    Color? canvasText,
    Color? crosshair,
    Color? selection,
    Color? hover,
    Color? snap,
    Color? preview,
    Color? unconnected,
    Color? profilePath,
    Color? gps,
    Color? gpsTrack,
    Color? stakeOut,
    Color? wireOk,
    Color? commentText,
    Color? background,
    Color? panel,
    Color? panelAlt,
    Color? menu,
    Color? dialog,
    Color? card,
    Color? cardHigh,
    Color? raised,
    Color? raisedTranslucent,
    Color? inset,
    Color? insetDeep,
    Color? overlay,
    Color? overlayStrong,
    Color? overlayFaint,
    Color? stripe,
    Color? divider,
    Color? scrim,
    Color? bubble,
    Color? tintInfo,
    Color? tintWarning,
    Color? fg,
    Color? fg87,
    Color? fg70,
    Color? fg60,
    Color? fg54,
    Color? fg38,
    Color? fg30,
    Color? fg24,
    Color? fg12,
    Color? fg10,
    Color? bodyText,
    Color? accent,
    Color? accentFill,
    Color? accentText,
    Color? accentIcon,
    Color? info,
    Color? infoFill,
    Color? codeText,
    Color? ok,
    Color? okAlt,
    Color? okFill,
    Color? positive,
    Color? warning,
    Color? caution,
    Color? attention,
    Color? amber,
    Color? highlight,
    Color? error,
    Color? chartGrid,
    Color? chartGround,
    Color? chartGroundDark,
    Color? chartPipe,
    Color? chartHgl,
    Color? chartLow,
    Color? chartHigh,
    Color? chartMax,
    Color? chartRating,
    Color? chartVapour,
  }) => CadPalette(
    brightness: brightness,
    canvas: canvas ?? this.canvas,
    gridMinor: gridMinor ?? this.gridMinor,
    gridMajor: gridMajor ?? this.gridMajor,
    axis: axis ?? this.axis,
    gridLabel: gridLabel ?? this.gridLabel,
    canvasText: canvasText ?? this.canvasText,
    crosshair: crosshair ?? this.crosshair,
    selection: selection ?? this.selection,
    hover: hover ?? this.hover,
    snap: snap ?? this.snap,
    preview: preview ?? this.preview,
    unconnected: unconnected ?? this.unconnected,
    profilePath: profilePath ?? this.profilePath,
    gps: gps ?? this.gps,
    gpsTrack: gpsTrack ?? this.gpsTrack,
    stakeOut: stakeOut ?? this.stakeOut,
    wireOk: wireOk ?? this.wireOk,
    commentText: commentText ?? this.commentText,
    background: background ?? this.background,
    panel: panel ?? this.panel,
    panelAlt: panelAlt ?? this.panelAlt,
    menu: menu ?? this.menu,
    dialog: dialog ?? this.dialog,
    card: card ?? this.card,
    cardHigh: cardHigh ?? this.cardHigh,
    raised: raised ?? this.raised,
    raisedTranslucent: raisedTranslucent ?? this.raisedTranslucent,
    inset: inset ?? this.inset,
    insetDeep: insetDeep ?? this.insetDeep,
    overlay: overlay ?? this.overlay,
    overlayStrong: overlayStrong ?? this.overlayStrong,
    overlayFaint: overlayFaint ?? this.overlayFaint,
    stripe: stripe ?? this.stripe,
    divider: divider ?? this.divider,
    scrim: scrim ?? this.scrim,
    bubble: bubble ?? this.bubble,
    tintInfo: tintInfo ?? this.tintInfo,
    tintWarning: tintWarning ?? this.tintWarning,
    fg: fg ?? this.fg,
    fg87: fg87 ?? this.fg87,
    fg70: fg70 ?? this.fg70,
    fg60: fg60 ?? this.fg60,
    fg54: fg54 ?? this.fg54,
    fg38: fg38 ?? this.fg38,
    fg30: fg30 ?? this.fg30,
    fg24: fg24 ?? this.fg24,
    fg12: fg12 ?? this.fg12,
    fg10: fg10 ?? this.fg10,
    bodyText: bodyText ?? this.bodyText,
    accent: accent ?? this.accent,
    accentFill: accentFill ?? this.accentFill,
    accentText: accentText ?? this.accentText,
    accentIcon: accentIcon ?? this.accentIcon,
    info: info ?? this.info,
    infoFill: infoFill ?? this.infoFill,
    codeText: codeText ?? this.codeText,
    ok: ok ?? this.ok,
    okAlt: okAlt ?? this.okAlt,
    okFill: okFill ?? this.okFill,
    positive: positive ?? this.positive,
    warning: warning ?? this.warning,
    caution: caution ?? this.caution,
    attention: attention ?? this.attention,
    amber: amber ?? this.amber,
    highlight: highlight ?? this.highlight,
    error: error ?? this.error,
    chartGrid: chartGrid ?? this.chartGrid,
    chartGround: chartGround ?? this.chartGround,
    chartGroundDark: chartGroundDark ?? this.chartGroundDark,
    chartPipe: chartPipe ?? this.chartPipe,
    chartHgl: chartHgl ?? this.chartHgl,
    chartLow: chartLow ?? this.chartLow,
    chartHigh: chartHigh ?? this.chartHigh,
    chartMax: chartMax ?? this.chartMax,
    chartRating: chartRating ?? this.chartRating,
    chartVapour: chartVapour ?? this.chartVapour,
  );

  /// The original look of the app.
  static const dark = CadPalette(
    brightness: Brightness.dark,
    canvas: Color(0xFF14171B),
    gridMinor: Color(0xFF20262D),
    gridMajor: Color(0xFF2B333C),
    axis: Color(0xFF3B4650),
    gridLabel: Color(0xFF546E7A),
    canvasText: Color(0xFFCFD8DC),
    crosshair: Color(0x66FFFFFF),
    selection: Color(0xFFFFD54F),
    hover: Color(0xFF80DEEA),
    snap: Color(0xFF69F0AE),
    preview: Color(0xFFB0BEC5),
    // (a lighter red than the original 0xFFFF1744: it is also the colour of error
    // texts, which need 4.5:1 on the panels)
    unconnected: Color(0xFFFF6E6E),
    profilePath: Color(0xFFCE93D8),
    gps: Color(0xFF29B6F6),
    gpsTrack: Color(0xFF4DD0E1),
    stakeOut: Color(0xFFFFEB3B),
    wireOk: Color(0xFFFFEE58),
    commentText: Color(0xFFFFF8E1),
    background: Color(0xFF14171B),
    panel: Color(0xFF1B1F24),
    panelAlt: Color(0xFF15181C),
    menu: Color(0xFF1B1F24),
    dialog: Color(0xFF1F2429),
    card: Color(0xFF232830),
    cardHigh: Color(0xFF2A2F36),
    raised: Color(0xFF232A31),
    raisedTranslucent: Color(0xF2262B32),
    inset: Color(0xFF15191E),
    insetDeep: Color(0xFF0E1114),
    overlay: Color(0xAA1B1F24),
    overlayStrong: Color(0xDD1B1F24),
    overlayFaint: Color(0x661B1F24),
    stripe: Color(0x0AFFFFFF),
    divider: Color(0xFF2B3138),
    scrim: Color.from(alpha: 0.5, red: 0, green: 0, blue: 0),
    bubble: Color(0xFF243447),
    tintInfo: Color(0xFF22303A),
    tintWarning: Color(0xFF2E2A1E),
    fg: Color(0xFFFFFFFF),
    fg87: Color(0xDDFFFFFF),
    fg70: Color(0xB3FFFFFF),
    fg60: Color(0x99FFFFFF),
    fg54: Color(0x8AFFFFFF),
    // hints and secondary labels: 4.5:1 on every surface (white38, the original,
    // gave 3.6:1 on the panels)
    fg38: Color(0x86FFFFFF),
    fg30: Color(0x4DFFFFFF),
    fg24: Color(0x3DFFFFFF),
    fg12: Color(0x1FFFFFFF),
    fg10: Color(0x1AFFFFFF),
    bodyText: Color(0xFFDDE3E8),
    accent: Color(0xFF42A5F5),
    accentFill: Color(0xFF2E7DD1),
    accentText: Color(0xFF90CAF9),
    accentIcon: Color(0xFF64B5F6),
    info: Color(0xFF81D4FA),
    infoFill: Color(0xFF29B6F6),
    codeText: Color(0xFFB3E5FC),
    ok: Color(0xFF66BB6A),
    okAlt: Color(0xFF4CAF50),
    okFill: Color(0xFF2E7D32),
    positive: Color(0xFFB2FF59),
    warning: Color(0xFFFFA726),
    caution: Color(0xFFFF9800),
    attention: Color(0xFFFFAB40),
    amber: Color(0xFFFFC107),
    highlight: Color(0xFFFFD54F),
    error: Color(0xFFFF6E6E),
    chartGrid: Color(0xFF2B333C),
    chartGround: Color(0xFF8D6E63),
    chartGroundDark: Color(0xFF6D4C41),
    chartPipe: Color(0xFF42A5F5),
    chartHgl: Color(0xFF66BB6A),
    chartLow: Color(0xFF29B6F6),
    chartHigh: Color(0xFFFFA726),
    chartMax: Color(0xFFFF7043),
    chartRating: Color(0xFFEF5350),
    chartVapour: Color(0xFFAB47BC),
  );

  /// Light surfaces with dark text: the text steps are near-black with the
  /// alpha raised so the secondary text keeps 4.5:1 on the panels; the
  /// accents are the darker shades of the same hues.
  static const light = CadPalette(
    brightness: Brightness.light,
    canvas: Color(0xFFFFFFFF),
    gridMinor: Color(0xFFEEF1F4),
    gridMajor: Color(0xFFD9DEE4),
    axis: Color(0xFFAAB4BE),
    gridLabel: Color(0xFF546E7A),
    canvasText: Color(0xFF37474F),
    crosshair: Color(0x73000000),
    selection: Color(0xFFD500F9),
    hover: Color(0xFF00838F),
    snap: Color(0xFF00A152),
    preview: Color(0xFF546E7A),
    unconnected: Color(0xFFD50000),
    profilePath: Color(0xFF8E24AA),
    gps: Color(0xFF0288D1),
    gpsTrack: Color(0xFF00838F),
    stakeOut: Color(0xFF8A6D00),
    wireOk: Color(0xFF7C6A00),
    commentText: Color(0xFF4E342E),
    background: Color(0xFFECEFF2),
    panel: Color(0xFFF6F7F9),
    panelAlt: Color(0xFFE8EBEF),
    menu: Color(0xFFF6F7F9),
    dialog: Color(0xFFFFFFFF),
    card: Color(0xFFEEF1F5),
    cardHigh: Color(0xFFE9EDF2),
    raised: Color(0xFFFFFFFF),
    raisedTranslucent: Color(0xF2FFFFFF),
    inset: Color(0xFFF1F3F6),
    insetDeep: Color(0xFFE6E9ED),
    overlay: Color(0xD9E3E7EC),
    overlayStrong: Color(0xEBFFFFFF),
    overlayFaint: Color(0x99E3E7EC),
    stripe: Color(0x0A000000),
    divider: Color(0xFFD5DAE0),
    scrim: Color(0x52000000),
    bubble: Color(0xFFE3EEFA),
    tintInfo: Color(0xFFE5F1F6),
    tintWarning: Color(0xFFFFF3DC),
    fg: Color(0xFF15191D),
    fg87: Color(0xDE111418),
    fg70: Color(0xC2111418),
    fg60: Color(0xAD111418),
    fg54: Color(0xA3111418),
    fg38: Color(0x99111418),
    fg30: Color(0x6B111418),
    fg24: Color(0x4D111418),
    fg12: Color(0x1F111418),
    fg10: Color(0x17111418),
    bodyText: Color(0xFF2A3036),
    accent: Color(0xFF1976D2),
    accentFill: Color(0xFF2E7DD1),
    accentText: Color(0xFF1565C0),
    accentIcon: Color(0xFF1565C0),
    info: Color(0xFF01579B),
    infoFill: Color(0xFF0288D1),
    codeText: Color(0xFF01579B),
    ok: Color(0xFF2B7530),
    okAlt: Color(0xFF2B7530),
    okFill: Color(0xFF2E7D32),
    positive: Color(0xFF33691E),
    warning: Color(0xFF9F5000),
    caution: Color(0xFF9F5000),
    attention: Color(0xFF9F5000),
    amber: Color(0xFF8A5A00),
    highlight: Color(0xFF8A5A00),
    error: Color(0xFFC62828),
    chartGrid: Color(0xFFDDE2E7),
    chartGround: Color(0xFF8D6E63),
    chartGroundDark: Color(0xFF6D4C41),
    chartPipe: Color(0xFF1E88E5),
    chartHgl: Color(0xFF388E3C),
    chartLow: Color(0xFF0288D1),
    chartHigh: Color(0xFFEF6C00),
    chartMax: Color(0xFFE64A19),
    chartRating: Color(0xFFD32F2F),
    chartVapour: Color(0xFF8E24AA),
  );

  // 1.6.0 UI: high contrast (View → Interface → High contrast): pure
  // backgrounds, text and secondary labels at 7:1 or more (WCAG AAA), strong
  // dividers and borders, brighter (dark) or deeper (light) accents
  static final CadPalette darkHigh = dark.copyWith(
    canvas: const Color(0xFF000000),
    gridMinor: const Color(0xFF262626),
    gridMajor: const Color(0xFF404040),
    axis: const Color(0xFF6E6E6E),
    gridLabel: const Color(0xFFB0BEC5),
    canvasText: const Color(0xFFFFFFFF),
    crosshair: const Color(0xB3FFFFFF),
    preview: const Color(0xFFE0E0E0),
    background: const Color(0xFF000000),
    panel: const Color(0xFF000000),
    panelAlt: const Color(0xFF0D0D0D),
    menu: const Color(0xFF000000),
    dialog: const Color(0xFF0A0A0A),
    card: const Color(0xFF141414),
    cardHigh: const Color(0xFF1C1C1C),
    raised: const Color(0xFF0F0F0F),
    raisedTranslucent: const Color(0xF70F0F0F),
    inset: const Color(0xFF050505),
    insetDeep: const Color(0xFF000000),
    overlay: const Color(0xE6000000),
    overlayStrong: const Color(0xF5000000),
    overlayFaint: const Color(0x99000000),
    stripe: const Color(0x1AFFFFFF),
    divider: const Color(0xFF8C8C8C),
    scrim: const Color(0x99000000),
    bubble: const Color(0xFF0D2A4A),
    tintInfo: const Color(0xFF0B2533),
    tintWarning: const Color(0xFF2E2400),
    fg: const Color(0xFFFFFFFF),
    fg87: const Color(0xFFFFFFFF),
    fg70: const Color(0xF2FFFFFF),
    fg60: const Color(0xEBFFFFFF),
    fg54: const Color(0xE6FFFFFF),
    fg38: const Color(0xD9FFFFFF),
    fg30: const Color(0xA6FFFFFF),
    fg24: const Color(0x99FFFFFF),
    fg12: const Color(0x66FFFFFF),
    fg10: const Color(0x4DFFFFFF),
    bodyText: const Color(0xFFFFFFFF),
    accent: const Color(0xFF82B1FF),
    accentFill: const Color(0xFF1E5BB8),
    accentText: const Color(0xFFBBDEFB),
    accentIcon: const Color(0xFFBBDEFB),
    info: const Color(0xFFB3E5FC),
    codeText: const Color(0xFFE1F5FE),
    ok: const Color(0xFFA5D6A7),
    okAlt: const Color(0xFF81C784),
    warning: const Color(0xFFFFCC80),
    caution: const Color(0xFFFFB74D),
    attention: const Color(0xFFFFD180),
    amber: const Color(0xFFFFE082),
    highlight: const Color(0xFFFFE57F),
    error: const Color(0xFFFF9E9E),
    unconnected: const Color(0xFFFF9E9E),
    chartGrid: const Color(0xFF4D4D4D),
  );

  static final CadPalette lightHigh = light.copyWith(
    canvas: const Color(0xFFFFFFFF),
    gridMinor: const Color(0xFFE0E0E0),
    gridMajor: const Color(0xFFB0B0B0),
    axis: const Color(0xFF6E6E6E),
    gridLabel: const Color(0xFF263238),
    canvasText: const Color(0xFF000000),
    crosshair: const Color(0xB3000000),
    preview: const Color(0xFF263238),
    background: const Color(0xFFFFFFFF),
    panel: const Color(0xFFFFFFFF),
    panelAlt: const Color(0xFFF0F0F0),
    menu: const Color(0xFFFFFFFF),
    dialog: const Color(0xFFFFFFFF),
    card: const Color(0xFFF2F2F2),
    cardHigh: const Color(0xFFEBEBEB),
    raised: const Color(0xFFFFFFFF),
    raisedTranslucent: const Color(0xF7FFFFFF),
    inset: const Color(0xFFF5F5F5),
    insetDeep: const Color(0xFFEBEBEB),
    overlay: const Color(0xEBFFFFFF),
    overlayStrong: const Color(0xF7FFFFFF),
    overlayFaint: const Color(0xB3FFFFFF),
    stripe: const Color(0x14000000),
    divider: const Color(0xFF5C5C5C),
    scrim: const Color(0x80000000),
    bubble: const Color(0xFFD6E8FF),
    tintInfo: const Color(0xFFDDEFF7),
    tintWarning: const Color(0xFFFFF0C2),
    fg: const Color(0xFF000000),
    fg87: const Color(0xFF000000),
    fg70: const Color(0xF2000000),
    fg60: const Color(0xEB000000),
    fg54: const Color(0xE6000000),
    fg38: const Color(0xD9000000),
    fg30: const Color(0xA6000000),
    fg24: const Color(0x99000000),
    fg12: const Color(0x66000000),
    fg10: const Color(0x4D000000),
    bodyText: const Color(0xFF000000),
    accent: const Color(0xFF0D47A1),
    accentFill: const Color(0xFF0D47A1),
    accentText: const Color(0xFF0D3C8C),
    accentIcon: const Color(0xFF0D3C8C),
    info: const Color(0xFF01416E),
    codeText: const Color(0xFF01416E),
    ok: const Color(0xFF1B5E20),
    okAlt: const Color(0xFF1B5E20),
    positive: const Color(0xFF254D16),
    warning: const Color(0xFF7A3D00),
    caution: const Color(0xFF7A3D00),
    attention: const Color(0xFF7A3D00),
    amber: const Color(0xFF664300),
    highlight: const Color(0xFF664300),
    error: const Color(0xFFA31515),
    unconnected: const Color(0xFFA31515),
    chartGrid: const Color(0xFFBDBDBD),
  );
}

/// The colours of the current theme: `Cad.fg70`, `Cad.panel`… (see
/// [CadPalette] for what each token is for). Read them in `build` and
/// `paint`, never into a `const` or a field that outlives a rebuild.
abstract final class Cad {
  static CadPalette _p = CadPalette.dark;

  /// The current palette.
  static CadPalette get palette => _p;
  static Brightness get brightness => _p.brightness;
  static bool get isLight => _p.brightness == Brightness.light;

  /// Switches the palette (see [CadThemeHost], which also rebuilds the tree).
  static void use(Brightness b) => _p = CadPalette.of(b);

  /// Runs [body] with [palette], then restores the current one: pictures
  /// made for another reader (the AI assistant) that must not follow the
  /// interface theme.
  static T paintWith<T>(CadPalette palette, T Function() body) {
    final saved = _p;
    _p = palette;
    try {
      return body();
    } finally {
      _p = saved;
    }
  }

  /// How a drawing colour (a layer's, a result overlay's) shows on the
  /// canvas: as it is on the dark canvas; on the light one with the usual
  /// CAD rule — white and near-white (luminance above 0.85) draw near-black,
  /// other light colours are darkened, hue kept, so nothing fades into the
  /// white background. The data keeps its colour, and plots keep theirs.
  static Color ink(Color c) {
    if (!isLight) return c;
    return _ink.putIfAbsent(c.toARGB32(), () => lightInk(c));
  }

  static final Map<int, Color> _ink = {};

  /// [ink] on the light canvas.
  static Color lightInk(Color c) {
    final l = c.computeLuminance();
    if (l > 0.85) return Color.from(alpha: c.a, red: 0x22 / 255, green: 0x26 / 255, blue: 0x2B / 255);
    // darkest a light colour is taken to: 4.2:1 against white
    const target = 0.20;
    if (l <= target) return c;
    final f = target / l;
    double channel(double v) {
      final lin = (v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble()) * f;
      return (lin <= 0.0031308 ? lin * 12.92 : 1.055 * math.pow(lin, 1 / 2.4) - 0.055).clamp(0.0, 1.0).toDouble();
    }

    return Color.from(alpha: c.a, red: channel(c.r), green: channel(c.g), blue: channel(c.b));
  }

  // canvas
  static Color get canvas => _p.canvas;
  static Color get gridMinor => _p.gridMinor;
  static Color get gridMajor => _p.gridMajor;
  static Color get axis => _p.axis;
  static Color get gridLabel => _p.gridLabel;
  static Color get canvasText => _p.canvasText;
  static Color get crosshair => _p.crosshair;
  static Color get selection => _p.selection;
  static Color get hover => _p.hover;
  static Color get snap => _p.snap;
  static Color get preview => _p.preview;
  static Color get unconnected => _p.unconnected;
  static Color get profilePath => _p.profilePath;
  static Color get gps => _p.gps;
  static Color get gpsTrack => _p.gpsTrack;
  static Color get stakeOut => _p.stakeOut;
  static Color get wireOk => _p.wireOk;
  static Color get commentText => _p.commentText;

  // surfaces
  static Color get background => _p.background;
  static Color get panel => _p.panel;
  static Color get panelAlt => _p.panelAlt;
  static Color get menu => _p.menu;
  static Color get dialog => _p.dialog;
  static Color get card => _p.card;
  static Color get cardHigh => _p.cardHigh;
  static Color get raised => _p.raised;
  static Color get raisedTranslucent => _p.raisedTranslucent;
  static Color get inset => _p.inset;
  static Color get insetDeep => _p.insetDeep;
  static Color get overlay => _p.overlay;
  static Color get overlayStrong => _p.overlayStrong;
  static Color get overlayFaint => _p.overlayFaint;
  static Color get stripe => _p.stripe;
  static Color get divider => _p.divider;
  static Color get scrim => _p.scrim;
  static Color get bubble => _p.bubble;
  static Color get tintInfo => _p.tintInfo;
  static Color get tintWarning => _p.tintWarning;

  // text and icons
  static Color get fg => _p.fg;
  static Color get fg87 => _p.fg87;
  static Color get fg70 => _p.fg70;
  static Color get fg60 => _p.fg60;
  static Color get fg54 => _p.fg54;
  static Color get fg38 => _p.fg38;
  static Color get fg30 => _p.fg30;
  static Color get fg24 => _p.fg24;
  static Color get fg12 => _p.fg12;
  static Color get fg10 => _p.fg10;
  static Color get bodyText => _p.bodyText;

  // accents
  static Color get accent => _p.accent;
  static Color get accentFill => _p.accentFill;
  static Color get accentText => _p.accentText;
  static Color get accentIcon => _p.accentIcon;
  static Color get info => _p.info;
  static Color get infoFill => _p.infoFill;
  static Color get codeText => _p.codeText;
  static Color get ok => _p.ok;
  static Color get okAlt => _p.okAlt;
  static Color get okFill => _p.okFill;
  static Color get positive => _p.positive;
  static Color get warning => _p.warning;
  static Color get caution => _p.caution;
  static Color get attention => _p.attention;
  static Color get amber => _p.amber;
  static Color get highlight => _p.highlight;
  static Color get error => _p.error;

  // charts
  static Color get chartGrid => _p.chartGrid;
  static Color get chartGround => _p.chartGround;
  static Color get chartGroundDark => _p.chartGroundDark;
  static Color get chartPipe => _p.chartPipe;
  static Color get chartHgl => _p.chartHgl;
  static Color get chartLow => _p.chartLow;
  static Color get chartHigh => _p.chartHigh;
  static Color get chartMax => _p.chartMax;
  static Color get chartRating => _p.chartRating;
  static Color get chartVapour => _p.chartVapour;
}

/// The theme chosen under View → Theme.
enum CadThemeMode { dark, light, system }

/// The current choice; [CadThemeHost] applies it.
final ValueNotifier<CadThemeMode> uiThemeMode = ValueNotifier<CadThemeMode>(CadThemeMode.dark);

/// The choice saved under the `theme` preference (dark when none).
CadThemeMode savedThemeMode() => CadThemeMode.values.firstWhere((m) => m.name == getPref('theme'), orElse: () => CadThemeMode.dark);

/// Chooses the theme and saves the choice.
void setThemeMode(CadThemeMode mode) {
  setPref('theme', mode.name);
  uiThemeMode.value = mode;
}

/// The brightness [mode] shows with the platform at [platform].
Brightness effectiveBrightness(CadThemeMode mode, Brightness platform) => switch (mode) {
  CadThemeMode.dark => Brightness.dark,
  CadThemeMode.light => Brightness.light,
  CadThemeMode.system => platform,
};

/// Applies the theme above the app: reads the saved choice at start-up,
/// follows [uiThemeMode] and, with [CadThemeMode.system], the platform
/// brightness. On a change it switches the palette and rebuilds and
/// repaints every widget below it in place — states, the projects and the
/// open dialogs stay.
class CadThemeHost extends StatefulWidget {
  const CadThemeHost({super.key, required this.builder});

  /// Builds the app with the material theme of [brightness].
  final Widget Function(BuildContext context, Brightness brightness) builder;

  @override
  State<CadThemeHost> createState() => _CadThemeHostState();
}

class _CadThemeHostState extends State<CadThemeHost> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    final saved = savedThemeMode();
    if (uiThemeMode.value != saved) uiThemeMode.value = saved;
    uiThemeMode.addListener(_update);
    uiHighContrast.addListener(_update); // 1.6.0 UI
    WidgetsBinding.instance.addObserver(this);
    Cad.use(_brightness());
  }

  @override
  void dispose() {
    uiThemeMode.removeListener(_update);
    uiHighContrast.removeListener(_update); // 1.6.0 UI
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Brightness _brightness() => effectiveBrightness(uiThemeMode.value, WidgetsBinding.instance.platformDispatcher.platformBrightness);

  @override
  void didChangePlatformBrightness() => _update();

  void _update() {
    if (!mounted) return;
    final b = _brightness();
    // (1.6.0 UI: the same brightness can change palette, by the high contrast)
    if (identical(CadPalette.of(b), Cad.palette)) return;
    Cad.use(b);
    setState(() {});
    // the widgets read the palette through static getters, without a
    // dependency on the Theme: rebuild them all, and repaint the custom
    // painters whose shouldRepaint only looks at their data
    void visit(Element e) {
      e.markNeedsBuild();
      if (e is RenderObjectElement) e.renderObject.markNeedsPaint();
      e.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, Cad.brightness);
}

/// The material theme of [brightness] (the current one when omitted).
ThemeData buildCadTheme([Brightness? brightness]) {
  final p = CadPalette.of(brightness ?? Cad.brightness);
  const seed = Color(0xFF1E88E5);
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: p.brightness, surface: p.panel);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: p.background,
    canvasColor: p.panel,
    visualDensity: VisualDensity.compact,
    dividerColor: p.divider,
    textTheme: const TextTheme(bodyMedium: TextStyle(fontSize: 12.5), bodySmall: TextStyle(fontSize: 11.5), labelLarge: TextStyle(fontSize: 12.5)),
    inputDecorationTheme: const InputDecorationTheme(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
    dataTableTheme: const DataTableThemeData(headingRowHeight: 30, dataRowMinHeight: 26, dataRowMaxHeight: 30, columnSpacing: 16, horizontalMargin: 8),
    tooltipTheme: const TooltipThemeData(waitDuration: Duration(milliseconds: 500)),
    menuTheme: const MenuThemeData(style: MenuStyle(visualDensity: VisualDensity.compact)),
    dialogTheme: DialogThemeData(backgroundColor: p.dialog),
  );
}
