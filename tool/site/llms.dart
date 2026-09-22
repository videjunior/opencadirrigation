part of '../site.dart';

// llms.txt (the llmstxt.org proposal) and llms-full.txt: what a language
// model needs to describe OpenCADIrrigation correctly, in Markdown and
// without the application shell. English, the canonical language of the
// project, with links to the page of every other language. The page texts
// come from `_en`; the technical facts below follow README.md, so update both
// when the app changes (and keep to the editorial rules: no competing
// products, no repository links or open-source claims).

/// Short facts, as `(label, value)`, shared by both files.
List<(String, String)> _facts() => [
  ('What', 'Browser-based CAD for designing pressurised irrigation systems (drip, micro-sprinkler, sprinkler, centre pivot and linear move) with a hydraulic engine, automatic pipe sizing, bill of materials and reports'),
  ('Price', 'Free for professional, academic and personal use; no account or sign-up'),
  ('Runs in', 'Chrome, Edge, Firefox and Safari on desktop, tablet and phone; installable as a PWA; nothing to download'),
  ('Privacy', 'Projects stay on the user\'s computer (browser storage and `.oci.json` files); nothing is uploaded to a server'),
  ('Languages', '${siteLanguages.length}: ${[for (final l in siteLanguages) _englishNames[l.code]].join(', ')}'),
  ('Project file', '`.oci.json`, readable JSON that holds the drawing, the catalogue, the parameters and the last results'),
  ('CAD and GIS exchange', 'DXF, DWG, KML/KMZ, shapefile, GeoJSON, CSV/XYZ survey points, GeoTIFF, georeferenced images, SVG and PDF'),
  ('Reports', 'PDF, Excel (XLSX), CSV and TXT'),
  ('Version', '$appVersion, updated $siteLastMod'),
  ('Site', siteUrl),
];

/// Language names in English, for the file that is written in English.
const _englishNames = {
  'id': 'Indonesian',
  'de': 'German',
  'en': 'English',
  'es': 'Spanish',
  'fr': 'French',
  'ha': 'Hausa',
  'sw': 'Swahili',
  'pt': 'Portuguese',
  'vi': 'Vietnamese',
  'tr': 'Turkish',
  'ru': 'Russian',
  'ar': 'Arabic',
  'ur': 'Urdu',
  'hi': 'Hindi',
  'mr': 'Marathi',
  'bn': 'Bengali',
  'pa': 'Punjabi',
  'te': 'Telugu',
  'zh': 'Chinese',
  'ja': 'Japanese',
};

/// "Deutsch (German)"; just "English" or "Hausa" when both names agree.
String _bothNames(String code) => languageNames[code] == _englishNames[code] ? _englishNames[code]! : '${languageNames[code]} (${_englishNames[code]})';

/// Sections of the reference that go beyond the web page, as
/// `(heading, Markdown body)`.
const _reference = [
  (
    'Design workflow',
    '''1. **Project details**: name, client, site, designer and notes, printed in the sheet title block and the reports; metric or US units.
2. **Background**: import a DXF, DWG, KML/KMZ, shapefile, survey CSV, GeoTIFF or satellite image, or draw boundaries, buildings and roads. Images out of scale are fitted by aligning two points. A georeference (UTM zone and origin) enables base maps, online elevation and KML/GeoJSON export.
3. **Terrain**: contour lines and spot heights drawn or imported, an elevation GeoTIFF, or elevation downloaded for a coordinate; contours generated from the model and a 3D view.
4. **Hydraulic layout**: water supply, pump, mainline, zone valves and, downstream of each valve, submains, laterals, drip tapes, single emitters and devices (filters, pressure regulators, meters, backflow preventers, air and check valves). A lateral-block generator (also along a curved guide such as a contour line) and a sprinkler-grid generator (square or triangular) do the repetitive work. Irrigated areas carry the crop, efficiency and water balance.
5. **Management**: system flows, i.e. which valves and pivots open together, with start time and duration; they can be grouped automatically within the supply flow and a maximum number of zones.
6. **Check**: unconnected items, pipes crossing without a junction, dead ends, zones without emitters, missing catalogue items, missing terrain.
7. **Design (F5)**: zones, mainline, telescoping, flushing, water hammer, valve wiring and materials; or only zones, only the mainline, or an analysis of the current diameters.
8. **Reports and plotting**: reports panel, PDF sheet with title block, legend, north arrow, scale bar and bill of materials; exports to other CAD, GIS and spreadsheets.'''
  ),
  (
    'Hydraulic engine',
    '''- Friction: Hazen-Williams (default) or Darcy-Weisbach (Swamee-Jain, Colebrook, laminar and transition), with the water viscosity from its temperature (20 °C by default).
- Minor losses as a share of the length (5 % by default) or from fitting coefficients; valves and devices by `h = K·Q^n + C`.
- Emitters by `q = k·H^x`, wetted radius by `R = a·H^b`; pressure-compensating and turbulent drippers, micro-sprinklers, sprinklers, bubblers, guns and demand points.
- Network solver: the Global Gradient Algorithm (Todini and Pilati), the method of EPANET, with pressure-dependent emitters, pumps, pressure-reducing valves and check valves, on a sparse LDLᵀ factorisation.
- Laterals and tapes are lumped into at most 100 nodes each (adjustable), so lines with hundreds of emitters stay fast.
- Terrain elevation at every node; emitter pressure accounts for ground level, riser height and burial depth.
- Uniformity: Christiansen CU, low-quarter DU, Keller-Karmeli emission uniformity EU (with the manufacturing CV and emitters per plant), statistical uniformity and flow variation; overlap CU for sprinklers with a wetted radius; a densogram adds up the water every sprinkler applies as drawn (arc, orientation and design pressure) and gives the rate map with CU, DU and the scheduling coefficient per irrigated area.
- Water hammer: wave celerity from pipe material and wall, Joukowsky surge, critical time 2L/a and comparison with the pipe pressure rating, including the valve closure time. It is an estimate, not a full transient simulation.
- Flushing of drip tapes with open ends at the flushing velocity (0.3 m/s and 1 m end pressure by default).
- The calculation runs in a Web Worker, off the interface thread.'''
  ),
  (
    'Pipe sizing and optimisation',
    '''- **Linear programming** (default): every pipe may be built from fractions of the candidate diameters; the programme minimises the annualised pipe cost plus the energy cost of the inlet pressure, subject to the pressure window of the critical emitters (end, highest and lowest point of every lateral), and repeats with the emitters found at the limits (up to four rounds).
- **Maximum velocity** method as the classic alternative (defaults 2.0 m/s in laterals, 1.5 m/s in submains, 2.0 m/s in the mainline).
- Greedy repair along the critical path, non-increasing diameters downstream and **telescoping** (up to 3 diameters per submain or mainline pipe by default).
- Pipe pressure classes respected in operation and under water hammer.
- The mainline is sized over all system flows with the energy weighted by the operating hours of each, with pump operating points and supply duties (flow, available and required pressure, deficit, annual energy).
- Economics: interest rate, term, energy tariff, pump efficiency and operating hours; costs in the currency of the user's region.
- **Design assistant**: every problem explained (what happened, why it matters, how to fix it), impossible settings detected, one-click corrections, *Fix automatically* and *Optimise design* (lowest annual cost that meets every requirement, kept only when it improves).'''
  ),
  (
    'Agronomy and scheduling',
    '''- Crop water requirement from ETo and Kc, water balance with available water, root depth and allowable depletion, application efficiency and wetted fraction.
- Readily available water, irrigation interval, gross and net depths and hours per event.
- Controller programme per system flow (days and start times), exportable as CSV.'''
  ),
  (
    'Valve wiring',
    '''- Controllers (stations, output voltage, cost) and wire routes drawn from the controller through the valves; every valve gets a station number by distance.
- Station and common wire sizes chosen at the lowest cost that keeps every solenoid above its minimum voltage (20 V by default) while it opens with the other valves of its system flow already on (inrush and holding currents, route lengths plus slack).
- Electrical report (route, wire lengths, sizes, solenoid voltage) and wires, controllers and connectors in the bill of materials; stations and simultaneous valves checked.'''
  ),
  (
    'Terrain',
    '''- Sources: drawn contour lines and spot heights, survey points (CSV, TXT, XYZ, PNEZD, decimal comma accepted), DXF/DWG polylines with elevation, KML with altitude, shapefiles with Z or an elevation attribute, elevation GeoTIFF and online elevation.
- Online elevation for a pasted coordinate (decimal, map link or degrees/minutes/seconds): free keyless services (Terrain Tiles on AWS Open Data from SRTM, and Open-Meteo with the Copernicus DEM).
- Digital terrain model by Delaunay triangulation (TIN) or inverse-distance interpolation; contours generated from the model; 3D view with the pipes draped on the ground; longitudinal profiles with the pipe and the hydraulic grade line.'''
  ),
  (
    'Centre pivots and linear moves',
    '''- Machines with radius, spans and towers, applied depth, cycle time, end pressure, sector angle and end gun, fed from the mainline as a demand.
- Report of towers, spans and sprinklers, and a check of the application rate against the soil intake limit.'''
  ),
  (
    'Component catalogue',
    '''- Seven groups: pipes, emitters with nozzles, tapes and driplines, valves and devices, pumps (Q-H curve), fittings and wires.
- Default catalogue: 17 pipes (PE 16–50 mm, PVC DN 35–250, HDPE 110 and 160, 6" steel), 9 emitter families, 6 tapes and driplines, 30 valves and devices (1" to 6"), 18 pumps (centrifugal 1 to 100 hp, submersible 3 to 30 hp), about 330 fittings and 12 copper wires (1 to 10 mm² and AWG 18 to 8), with illustrative prices.
- 14 manufacturer packs (259 items) built from published data sheets: Hunter, Rain Bird, Toro, Netafim, Rivulis, NaanDanJain, Jain, Nelson and Senninger (sprinklers, micro-sprinklers, drippers, tapes and driplines, pivot sprinklers, big guns, valves and regulators), Irritec (driplines and drippers), Bermad (hydraulic valves), Schneider (centrifugal and submersible pumps), and Amanco Wavin and Multilit (PVC irrigation pipes). Nozzle curves are fitted to the manufacturers' tables; prices are left to the user.
- The catalogue editor imports and exports JSON, CSV and Excel; packs in the `.oci.cat` JSON format load from a file or a URL, so dealers can publish their own.'''
  ),
  (
    'Reports and plotting',
    '''- Reports: zone summary, pipes, emitters, mainline and supply duties, bill of materials with automatically selected fittings (couplers, elbows, tees, crosses, reducers, end caps, take-offs, risers), water requirements, agronomy, controller schedule, flushing, water hammer, pivots and spans, valve wiring, hydraulic grade line chart, terrain profile, densogram and messages.
- PDF sheet from A4 to A0, Letter and Tabloid, automatic or fixed scale, title block, legend, north arrow, scale bar, bill of materials on the sheet and attached report pages.
- Every table exports to PDF, Excel (one sheet per table, numbers as numbers), CSV and TXT.'''
  ),
  (
    'File formats',
    '''| Format | Import | Export |
|---|---|---|
| `.oci.json` project | yes | yes |
| DXF | R12 to 2018: lines, polylines with bulges, circles, arcs, ellipses, splines (NURBS), hatches, solids, texts, points, layers, blocks and dimensions | R12, by layer |
| DWG | R13/R14 (partial), 2000, 2004, 2007, 2010, 2013 and 2018: the same entities, layers, blocks and dimensions | 2000 (AC1015) |
| KML / KMZ | placemarks, folders as layers, altitude as elevation | folders per layer, WGS84 |
| Shapefile (zip with DBF, PRJ, CPG) | points, lines, polygons, Z variants, attributes in UTF-8 or Latin-1 | — |
| GeoJSON | — | FeatureCollection with attributes |
| CSV, TXT | survey points | report tables, controller programme |
| XYZ, PNEZD | survey points | — |
| GeoTIFF | elevation grid or background image | — |
| JPG, PNG, world file | background image, georeferenced or aligned by 2 points | — |
| SVG | — | sheet in millimetres, one group per layer |
| PDF | — | sheet and reports |
| XLSX | catalogue prices | reports and catalogue |'''
  ),
  (
    'Storage, privacy and network access',
    '''- Autosave in the browser, recent projects, the last 10 versions of every project and recovery on start-up.
- Save and Open work with `.oci.json` files on the user's disk; nothing is sent to a server and there is no account.
- The internet is reached only when the user asks: online elevation, base maps (OpenStreetMap and other tile services, or Google Maps with the user's own key) and catalogues loaded by URL.'''
  ),
  (
    'Known limitations',
    '''- Looped mainlines are sized along tree paths (an approximation) and then checked by the full analysis.
- The DWG writer produces version 2000 (AC1015) files with lines, polylines, circles, arcs, points and texts (hatches and splines are written as outlines and polylines).
- Steady-state hydraulics: water hammer is a Joukowsky estimate; there is no fertigation design.
- Valve wiring is conventional (a station conductor per valve and a shared common, 24 V AC solenoids), with routes drawn by the user; two-wire decoder systems are not modelled.
- Pivots are modelled as machines with span tables and a demand on the mainline, without nozzle-by-nozzle design.
- No simultaneous editing; projects are shared as `.oci.json` files.'''
  ),
];

/// Deep links, as `(query, effect)`.
const _deepLinks = [
  ('?example=<id>', 'opens a ready example (ids in the table above)'),
  ('?tutorial=1', 'opens the interactive tutorial (any step number works)'),
  ('?design=1', 'designs the project on load'),
  ('?lang=<code>', 'interface language for this visit (codes in the language list)'),
];

String _examplesTable(String Function(SiteExample) url) {
  final en = siteText('en');
  return [
    '| Id | Example | What it shows |',
    '|---|---|---|',
    for (final ex in en.examples) '| `${ex.id}` | [${ex.title}](${url(ex)}) | ${ex.text} |',
  ].join('\n');
}

/// llms.txt: the summary a language model reads first.
String renderLlmsTxt() {
  final en = siteText('en');
  final b = StringBuffer()
    ..writeln('# OpenCADIrrigation')
    ..writeln()
    ..writeln('> ${en.faq.first.$2}')
    ..writeln()
    ..writeln(en.intro)
    ..writeln();
  for (final (label, value) in _facts()) {
    b.writeln('- $label: $value');
  }
  b
    ..writeln()
    ..writeln('## Application')
    ..writeln()
    ..writeln('- [OpenCADIrrigation]($siteUrl): the app and its page in English; the app opens in the visitor\'s language when it speaks it')
    ..writeln('- [${en.tutorial}]($siteUrl?tutorial=1): a guided tour of every function on a sample project')
    ..writeln('- [Sized example]($siteUrl?design=1): the sample orchard, designed as soon as it opens')
    ..writeln()
    ..writeln('## Reference')
    ..writeln()
    ..writeln('- [Complete reference](${siteUrl}llms-full.txt): features, design workflow, hydraulic methods, sizing, catalogues, file formats, examples, deep links, limitations and FAQ in one Markdown file')
    ..writeln()
    ..writeln('## ${en.examplesTitle}')
    ..writeln()
    ..writeln(en.examplesIntro)
    ..writeln();
  for (final ex in en.examples) {
    b.writeln('- [${ex.title}]($siteUrl?example=${ex.id}): ${ex.text}');
  }
  b
    ..writeln()
    ..writeln('## Other languages')
    ..writeln()
    ..writeln('The same page, written in each language of the app:')
    ..writeln();
  for (final l in siteLanguages.where((l) => !l.isRoot)) {
    b.writeln('- [${_bothNames(l.code)}](${l.url}): ${siteText(l.code).title}');
  }
  b
    ..writeln()
    ..writeln('## Optional')
    ..writeln()
    ..writeln('- [Sitemap](${siteUrl}sitemap.xml): every language page with its hreflang alternates');
  return b.toString();
}

/// llms-full.txt: everything a language model may need, in one file.
String renderLlmsFullTxt() {
  final en = siteText('en');
  final b = StringBuffer()
    ..writeln('# OpenCADIrrigation: complete reference')
    ..writeln()
    ..writeln('> ${en.faq.first.$2}')
    ..writeln()
    ..writeln('This file describes OpenCADIrrigation for language models and other automated readers. The application itself is at $siteUrl; a summary is at ${siteUrl}llms.txt. Version $appVersion, updated $siteLastMod.')
    ..writeln()
    ..writeln('## At a glance')
    ..writeln()
    ..writeln('| | |')
    ..writeln('|---|---|')
    ..writeln('| Name | OpenCADIrrigation (one word, "CAD" in capitals) |');
  for (final (label, value) in _facts()) {
    b.writeln('| $label | $value |');
  }
  b
    ..writeln()
    ..writeln('## Who it is for')
    ..writeln()
    ..writeln(en.faq.firstWhere((f) => f.$1 == 'Who is it for?').$2)
    ..writeln()
    ..writeln('## ${en.featuresTitle}')
    ..writeln();
  for (final (name, text) in en.features) {
    b
      ..writeln('### $name')
      ..writeln()
      ..writeln(text)
      ..writeln();
  }
  b
    ..writeln('## ${en.howTitle}')
    ..writeln();
  for (final (i, (name, text)) in en.how.indexed) {
    b.writeln('${i + 1}. **$name.** $text');
  }
  b.writeln();
  for (final (heading, body) in _reference) {
    b
      ..writeln('## $heading')
      ..writeln()
      ..writeln(body)
      ..writeln();
  }
  b
    ..writeln('## ${en.examplesTitle}')
    ..writeln()
    ..writeln(en.examplesIntro)
    ..writeln()
    ..writeln(_examplesTable((ex) => '$siteUrl?example=${ex.id}'))
    ..writeln()
    ..writeln('## Deep links')
    ..writeln()
    ..writeln('Every page of the site accepts these parameters, for example $siteUrl?example=garden or ${siteUrl}pt/?tutorial=1:')
    ..writeln();
  for (final (query, effect) in _deepLinks) {
    b.writeln('- `$query`: $effect');
  }
  b
    ..writeln()
    ..writeln('## ${en.faqTitle}')
    ..writeln();
  for (final (q, a) in en.faq) {
    b
      ..writeln('### $q')
      ..writeln()
      ..writeln(a)
      ..writeln();
  }
  b
    ..writeln('## Languages')
    ..writeln()
    ..writeln('The interface, the reports, the tutorial and the example projects are available in ${siteLanguages.length} languages. The app opens in the first language of the browser that it speaks, else in English. Each language has its own page:')
    ..writeln()
    ..writeln('| Language | Code | Page | Description on that page |')
    ..writeln('|---|---|---|---|');
  for (final l in siteLanguages) {
    b.writeln('| ${_bothNames(l.code)} | `${l.code}` | ${l.url} | ${siteText(l.code).description} |');
  }
  b
    ..writeln()
    ..writeln('## Citing')
    ..writeln()
    ..writeln('OpenCADIrrigation, version $appVersion. $siteUrl');
  return b.toString();
}
