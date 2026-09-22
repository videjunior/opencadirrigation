/// The public web pages of opencadirrigation.com, rendered from one template
/// in every interface language of the app: English at the root (`/`, the
/// Flutter entry page), the others under their language code (`/pt/`,
/// `/es/`, `/de/`, `/zh/`, …), plus the sitemap and the 404 page. The
/// Portuguese, English and Spanish texts are below; the other languages live
/// in `tool/site/<code>.dart`.
///
/// Search engines cannot read what Flutter paints on its canvas, so every
/// entry page carries the same content as real HTML: heading, description,
/// feature list, ready examples and FAQ. It is shown while the app loads and
/// hidden (kept in the DOM) on Flutter's first frame. Each page declares its
/// language, a self canonical, the hreflang cluster and JSON-LD.
///
/// Language models read the site too: robots.txt welcomes the AI crawlers by
/// name, `llms.txt` (the llmstxt.org summary) and `llms-full.txt` (the whole
/// reference in Markdown, `tool/site/llms.dart`) give them the facts without
/// the app shell, and the JSON-LD carries the FAQ, the steps, the examples and
/// the subject entities (Wikipedia/Wikidata) in every language.
///
/// `dart run tool/gen_site.dart` writes the files; the test
/// `test/web_metadata_test.dart` fails when they drift from this template.
library;

import 'dart:convert';

import 'package:opencadirrigation/app/i18n.dart' show languageNames, languageTag, rtlLanguages, supportedLanguages;
import 'package:opencadirrigation/app/version.dart' show appVersion;

part 'site/ar.dart';
part 'site/bn.dart';
part 'site/de.dart';
part 'site/fr.dart';
part 'site/ha.dart';
part 'site/hi.dart';
part 'site/id.dart';
part 'site/ja.dart';
part 'site/llms.dart';
part 'site/mr.dart';
part 'site/pa.dart';
part 'site/ru.dart';
part 'site/sw.dart';
part 'site/te.dart';
part 'site/tr.dart';
part 'site/ur.dart';
part 'site/vi.dart';
part 'site/zh.dart';

const siteUrl = 'https://opencadirrigation.com/';

/// Google Analytics measurement id of the site.
const analyticsId = 'G-3M0P4T8V2T';
const siteLastMod = '2026-09-22';

/// IndexNow key (Bing, Yandex, Seznam, Naver…): published as `/<key>.txt` so
/// `dart run tool/indexnow.dart` can announce changed pages after a deploy.
/// Bing's index also feeds the answers of Copilot and ChatGPT search.
const indexNowKey = 'b2ba822c8eb67b60cb661d7a42eb9ef9';

/// Languages of the site, one entry page per interface language of the app,
/// in the order of its language menu: code, BCP-47 tag, Open Graph locale,
/// page path. English is the root page: what a visitor gets when nothing has
/// chosen a language for them (the app then follows the machine language and
/// falls back to English too). Every other language lives under its code,
/// where the app reads it back (`languageFromPath`).
final siteLanguages = [
  for (final code in supportedLanguages) SiteLang(code, languageTag(code), _ogLocales[code]!, code == 'en' ? '' : '$code/'),
];

/// Open Graph locale of each language (the country is the one social
/// networks expect for it).
const _ogLocales = {
  'id': 'id_ID',
  'de': 'de_DE',
  'en': 'en_US',
  'es': 'es_ES',
  'fr': 'fr_FR',
  'ha': 'ha_NG',
  'sw': 'sw_KE',
  'pt': 'pt_BR',
  'vi': 'vi_VN',
  'tr': 'tr_TR',
  'ru': 'ru_RU',
  'ar': 'ar_AR',
  'ur': 'ur_PK',
  'hi': 'hi_IN',
  'mr': 'mr_IN',
  'bn': 'bn_IN',
  'pa': 'pa_IN',
  'te': 'te_IN',
  'zh': 'zh_CN',
  'ja': 'ja_JP',
};

class SiteLang {
  const SiteLang(this.code, this.tag, this.ogLocale, this.path);
  final String code;
  final String tag;
  final String ogLocale;

  /// Path of the page relative to the site root ('' for the root page).
  final String path;
  String get url => '$siteUrl$path';
  bool get isRoot => path.isEmpty;

  /// Whether the text runs right to left (Arabic, Urdu): the readable page
  /// content is laid out that way; the app keeps its own layout.
  bool get rtl => rtlLanguages.contains(code);

  /// ` dir="rtl"` for the elements holding text of a right-to-left language.
  String get dirAttr => rtl ? ' dir="rtl"' : '';

  /// Text direction, for a language name standing among names in other
  /// scripts (the attribute also isolates it from its neighbours).
  String get dir => rtl ? 'rtl' : 'ltr';

  /// Output file of the page inside `web/`.
  String get file => '${path}index.html';
}

SiteLang siteLang(String code) => siteLanguages.firstWhere((l) => l.code == code);

/// A gallery example as shown on the page.
class SiteExample {
  const SiteExample(this.id, this.title, this.text);
  final String id;
  final String title;
  final String text;
}

class SiteText {
  const SiteText({
    required this.title,
    required this.description,
    required this.keywords,
    required this.h1,
    required this.tagline,
    required this.intro,
    required this.openApp,
    required this.tutorial,
    required this.seeExamples,
    required this.featuresTitle,
    required this.features,
    required this.howTitle,
    required this.how,
    required this.examplesTitle,
    required this.examplesIntro,
    required this.examples,
    required this.faqTitle,
    required this.faq,
    required this.loading,
    required this.slow,
    required this.noScript,
    required this.otherLanguages,
    required this.footer,
    required this.subCategory,
    required this.screenshotLabel,
    required this.notFoundTitle,
    required this.notFoundText,
    required this.notFoundHome,
  });
  final String title;
  final String description;
  final String keywords;
  final String h1;
  final String tagline;
  final String intro;
  final String openApp;
  final String tutorial;
  final String seeExamples;
  final String featuresTitle;
  final List<(String, String)> features;
  final String howTitle;
  final List<(String, String)> how;
  final String examplesTitle;
  final String examplesIntro;
  final List<SiteExample> examples;
  final String faqTitle;
  final List<(String, String)> faq;
  final String loading;
  final String slow;
  final String noScript;
  final String otherLanguages;
  final String footer;
  final String subCategory;
  final String screenshotLabel;
  final String notFoundTitle;
  final String notFoundText;
  final String notFoundHome;
}

const _pt = SiteText(
  title: 'OpenCADIrrigation: CAD de projeto de irrigação no navegador',
  description: 'CAD gratuito de projeto de irrigação no navegador: gotejamento, microaspersão, aspersão e pivô central, cálculo hidráulico, lista de materiais e DXF/DWG.',
  keywords: 'projeto de irrigação, CAD irrigação, software de irrigação, irrigação pressurizada, gotejamento, microaspersão, aspersão, pivô central, dimensionamento hidráulico, dimensionamento de tubulação, uniformidade de irrigação, DXF, DWG, irrigação de jardim, irrigação agrícola',
  h1: 'CAD gratuito para projeto de irrigação pressurizada',
  tagline: 'Desenhe, dimensione e documente sistemas de gotejamento, microaspersão, aspersão e pivô central. Direto no navegador, sem instalar nada, com os projetos guardados no seu computador.',
  intro: 'O OpenCADIrrigation reúne num só lugar o desenho CAD, a rede hidráulica e o cálculo: você traça a área, lança laterais, válvulas e linha principal, aperta F5 e recebe diâmetros, pressões, uniformidade, turnos de operação, lista de materiais e relatórios prontos para imprimir. Funciona em 20 idiomas e segue o idioma do seu computador.',
  openApp: 'Abrir o app',
  tutorial: 'Tutorial interativo',
  seeExamples: 'Ver exemplos prontos',
  featuresTitle: 'O que o OpenCADIrrigation faz',
  features: [
    ('Desenho CAD completo', 'Linhas, polilinhas, arcos, splines, hachuras, cotas, textos e camadas, com snaps, seleção por janela, grips e atalhos no estilo AutoCAD (L, PL, C, D, ZE…).'),
    ('Rede hidráulica', 'Fontes de água, bombas, linha principal, válvulas de zona, laterais com emissores, fitas e tubos gotejadores, filtros, reguladores de pressão, hidrômetros e junções; geradores de bloco de laterais e de grade de aspersores.'),
    ('Motor hidráulico validado', 'Hazen-Williams e Darcy-Weisbach, perdas localizadas, emissores q = k·Hˣ, solver de rede pelo Global Gradient Algorithm (como o EPANET), curvas de bomba e ponto de operação, golpe de aríete e análise de lavagem.'),
    ('Dimensionamento automático', 'Programação linear ou velocidade máxima, respeitando a janela de pressão dos emissores e a classe dos tubos, com balanço entre custo de tubulação e energia, telescopagem de diâmetros e turnos de operação.'),
    ('Terreno e relevo', 'Curvas de nível, cotas de ponto, modelo digital do terreno por triangulação, elevação baixada da internet a partir de uma coordenada, perfis longitudinais e linha piezométrica sobre o terreno.'),
    ('Relatórios e materiais', 'Zonas, tubos, emissores, uniformidade (CU, DU, EU), requisitos hídricos por cultura, programa do controlador e lista de materiais com conexões; exportação em PDF, Excel, CSV e TXT.'),
    ('Troca de arquivos', 'Importa DXF, DWG, KML/KMZ, SHP, CSV/XYZ, GeoTIFF e imagens georreferenciadas; exporta DXF, DWG, PDF com prancha, SVG, KML, KMZ e GeoJSON.'),
    ('Catálogos de fabricantes', 'Catálogos de fabricantes em JSON (Netafim, Rivulis, Jain, Toro, Rain Bird, Nelson, Hunter, NaanDanJain, Senninger, Irritec, Bermad, Schneider, Amanco Wavin, Multilit) prontos para usar, além de pacotes próprios carregados por arquivo ou URL.'),
  ],
  howTitle: 'Como funciona',
  how: [
    ('Desenhe ou importe a área', 'Traga um DXF, DWG, KML ou uma imagem de satélite, ou desenhe o talhão, o jardim ou o campo diretamente. Adicione curvas de nível ou baixe a elevação pela coordenada.'),
    ('Monte a rede', 'Gere blocos de laterais ou grades de aspersores com um clique, posicione válvulas, bomba e fonte de água e ligue tudo pela linha principal.'),
    ('Projete e documente', 'Pressione F5: o app dimensiona zonas e linha principal, verifica pressões e velocidades e produz relatórios, lista de materiais e a prancha em PDF.'),
  ],
  examplesTitle: 'Exemplos prontos para abrir',
  examplesIntro: 'Cada projeto abre completo e calcula com F5. Use-os para conhecer o app ou como ponto de partida.',
  examples: [
    SiteExample('orchard', 'Pomar', 'Microaspersão em citros e gotejamento em uva, poço com bomba e filtro, terreno em declive.'),
    SiteExample('garden', 'Jardim residencial', 'Sprays pop-up, rotores e gotejamento nos canteiros, ligados à rede pública com hidrômetro e anti-refluxo.'),
    SiteExample('sportsField', 'Campo de futebol', 'Campo oficial com aspersores de impacto em cinco linhas, reservatório, bomba e turnos noturnos.'),
    SiteExample('rowCrop', 'Lavoura gotejada', 'Quatro talhões de tomate com fita gotejadora, filtro de tela, bomba e declive de 1 %.'),
    SiteExample('pivot', 'Pivô central', 'Pivô de 300 m em milho alimentado por poço e bomba, com relatório de torres, vãos e bocais.'),
    SiteExample('greenhouse', 'Estufa de hortaliças', 'Quatro túneis com tubo gotejador autocompensante, reservatório, bomba pequena e filtro de discos.'),
    SiteExample('nursery', 'Viveiro de mudas', 'Canteiros com microaspersores suspensos em malha 4 × 4 m, caixa d’água elevada e bomba pequena.'),
    SiteExample('coffee', 'Cafezal em curvas de nível', 'Laterais curvas que seguem as curvas de nível da encosta, tubo gotejador PC, poço e bomba.'),
    SiteExample('bananas', 'Bananal', 'Microaspersores autocompensantes em 5 × 5 m, poço com bomba submersa e filtro de discos.'),
    SiteExample('sugarcane', 'Cana-de-açúcar subsuperficial', 'Tubo gotejador PC enterrado a 0,3 m em laterais de 180 m, filtro de tela e ventosa.'),
    SiteExample('gravity', 'Gotejamento por gravidade', 'Reservatório 40 m acima dos talhões, sem bomba, com válvula reguladora de pressão na adutora.'),
    SiteExample('pasture', 'Pastagem em aspersão', 'Três piquetes com linhas de aspersores de impacto em 12 × 18 m, reservatório e bomba.'),
    SiteExample('golf', 'Buraco de golfe', 'Tee com sprays, fairway com rotores em malha triangular e green com rotores no perímetro.'),
    SiteExample('sectorPivot', 'Pivô setorial com canhão', 'Pivô de 250 m que gira 270° com canhão final, lago, bomba de 20 cv e registro.'),
    SiteExample('linear', 'Pivô linear', 'Lateral móvel de 392 m percorrendo 800 m ao longo de um canal, com captação e bomba.'),
  ],
  faqTitle: 'Perguntas frequentes',
  faq: [
    ('O que é o OpenCADIrrigation?', 'O OpenCADIrrigation é um aplicativo web gratuito para projetar sistemas de irrigação pressurizada: um CAD com motor hidráulico que desenha a rede, dimensiona as tubulações, verifica pressões e uniformidade e produz a lista de materiais e os relatórios, do jardim residencial ao pivô central.'),
    ('O OpenCADIrrigation é gratuito?', 'Sim. É gratuito para uso profissional, acadêmico e pessoal, sem cadastro.'),
    ('Para quem ele é?', 'Para projetistas de irrigação agrícola e paisagística, agrônomos e engenheiros, revendas de equipamentos, professores e estudantes. O tutorial interativo e 15 exemplos prontos permitem começar sem ler manual.'),
    ('Preciso instalar alguma coisa?', 'Não. Ele roda em Chrome, Edge, Firefox e Safari, no computador, no tablet e no celular, e pode ser instalado como aplicativo (PWA) para abrir em janela própria.'),
    ('Meus projetos ficam na nuvem?', 'Não. Os projetos são salvos no seu navegador e em arquivos .oci.json que você guarda onde quiser. Só a elevação online e os mapas base acessam a internet, quando você pede.'),
    ('Como é feito o cálculo hidráulico?', 'Perda de carga por Hazen-Williams ou Darcy-Weisbach, emissores por q = k·Hˣ e a rede inteira resolvida pelo Global Gradient Algorithm, o método do EPANET. As tubulações são dimensionadas por programação linear dentro da janela de pressão dos emissores, e o projeto verifica também uniformidade (CU, DU, EU), golpe de aríete e lavagem.'),
    ('Funciona com AutoCAD e outros CADs?', 'Sim. Importa e exporta DXF e DWG (AutoCAD 2000 a 2018), além de KML/KMZ do Google Earth, shapefile, GeoJSON, SVG e PDF.'),
    ('Em que idiomas está disponível?', 'Em 20 idiomas, os mesmos deste site (a lista está no rodapé da página). O app abre no idioma do seu computador e você pode trocar a qualquer momento em Ver → Idioma.'),
  ],
  loading: 'Carregando o CAD de irrigação…',
  slow: 'O carregamento está demorando. Verifique a conexão ou recarregue a página; o conteúdo acima já pode ser lido.',
  noScript: 'O OpenCADIrrigation precisa de JavaScript para funcionar. Ative o JavaScript no navegador e recarregue a página.',
  otherLanguages: 'Idiomas',
  footer: 'Catálogos de fabricantes e exemplos de projeto podem ser enviados em formato JSON para inclusão no OpenCADIrrigation.',
  subCategory: 'CAD para irrigação',
  screenshotLabel: 'Projeto de irrigação dimensionado com resultados por zona',
  notFoundTitle: 'Página não encontrada',
  notFoundText: 'O endereço não existe neste site. O OpenCADIrrigation é um único aplicativo; abra-o pela página inicial.',
  notFoundHome: 'Ir para o OpenCADIrrigation',
);

const _en = SiteText(
  title: 'OpenCADIrrigation: browser-based irrigation design CAD',
  description: 'Free browser CAD for irrigation design: drip, micro-sprinklers, sprinklers and centre pivots, hydraulic pipe sizing, bill of materials, DXF/DWG and PDF.',
  keywords: 'irrigation design software, irrigation CAD, drip irrigation design, sprinkler design, centre pivot, hydraulic design, pipe sizing, irrigation uniformity, DXF, DWG, landscape irrigation, agricultural irrigation, free irrigation software',
  h1: 'Free CAD for pressurised irrigation design',
  tagline: 'Draw, size and document drip, micro-sprinkler, sprinkler and centre-pivot systems. Right in the browser, nothing to install, with your projects kept on your own computer.',
  intro: 'OpenCADIrrigation brings CAD drawing, the hydraulic network and the calculation together: trace the area, lay out laterals, valves and the mainline, press F5 and get pipe sizes, pressures, uniformity, operating shifts, a bill of materials and printable reports. Available in 20 languages, following your computer\'s language.',
  openApp: 'Open the app',
  tutorial: 'Interactive tutorial',
  seeExamples: 'See ready examples',
  featuresTitle: 'What OpenCADIrrigation does',
  features: [
    ('Full CAD drawing', 'Lines, polylines, arcs, splines, hatches, dimensions, text and layers, with snaps, window selection, grips and AutoCAD-style shortcuts (L, PL, C, D, ZE…).'),
    ('Hydraulic network', 'Water supplies, pumps, mainline, zone valves, laterals with emitters, drip tapes and driplines, filters, pressure regulators, meters and junctions; lateral-block and sprinkler-grid generators.'),
    ('Validated hydraulic engine', 'Hazen-Williams and Darcy-Weisbach, minor losses, emitters q = k·Hˣ, network solver by the Global Gradient Algorithm (as in EPANET), pump curves and operating point, water hammer and flushing analysis.'),
    ('Automatic sizing', 'Linear programming or maximum velocity, honouring the emitter pressure window and pipe pressure classes, trading pipe cost against energy, telescoping diameters and operating shifts.'),
    ('Terrain and relief', 'Contours, spot heights, a digital terrain model by triangulation, elevation downloaded from the internet at a coordinate, longitudinal profiles and the hydraulic grade line over the ground.'),
    ('Reports and materials', 'Zones, pipes, emitters, uniformity (CU, DU, EU), crop water requirements, controller programme and a bill of materials with fittings; export to PDF, Excel, CSV and TXT.'),
    ('File exchange', 'Imports DXF, DWG, KML/KMZ, SHP, CSV/XYZ, GeoTIFF and georeferenced images; exports DXF, DWG, PDF sheets, SVG, KML, KMZ and GeoJSON.'),
    ('Manufacturer catalogues', 'Manufacturer catalogues in JSON (Netafim, Rivulis, Jain, Toro, Rain Bird, Nelson, Hunter, NaanDanJain, Senninger, Irritec, Bermad, Schneider, Amanco Wavin, Multilit) ready to use, plus your own packs loaded from a file or a URL.'),
  ],
  howTitle: 'How it works',
  how: [
    ('Draw or import the area', 'Bring a DXF, DWG, KML or a satellite image, or draw the field, garden or pitch directly. Add contours or download the elevation from a coordinate.'),
    ('Build the network', 'Generate lateral blocks or sprinkler grids in one click, place valves, pump and water supply and connect everything with the mainline.'),
    ('Design and document', 'Press F5: the app sizes zones and mainline, checks pressures and velocities and produces reports, the bill of materials and the PDF sheet.'),
  ],
  examplesTitle: 'Ready examples to open',
  examplesIntro: 'Every project opens complete and designs with F5. Use them to get to know the app or as a starting point.',
  examples: [
    SiteExample('orchard', 'Orchard', 'Micro-sprinklers on citrus and drip on grapes, well with pump and filter, sloping ground.'),
    SiteExample('garden', 'Residential garden', 'Pop-up sprays, rotors and drip in the beds, fed by the mains through a meter and a backflow preventer.'),
    SiteExample('sportsField', 'Football pitch', 'Full-size pitch with impact sprinklers in five rows, reservoir, pump and night-time shifts.'),
    SiteExample('rowCrop', 'Drip row crop', 'Four tomato blocks on drip tape, screen filter, pump and a 1 % slope.'),
    SiteExample('pivot', 'Centre pivot', 'A 300 m pivot on maize fed by a well and a pump, with a tower, span and sprinkler report.'),
    SiteExample('greenhouse', 'Vegetable greenhouse', 'Four tunnels on pressure-compensating dripline, tank, small pump and disc filter.'),
    SiteExample('nursery', 'Plant nursery', 'Beds under overhead micro-sprinklers on a 4 × 4 m grid, elevated tank and small pump.'),
    SiteExample('coffee', 'Coffee on contour lines', 'Curved laterals following the hillside contours, PC dripline, well and pump.'),
    SiteExample('bananas', 'Banana plantation', 'Pressure-compensating micro-sprinklers at 5 × 5 m, well with submersible pump and disc filter.'),
    SiteExample('sugarcane', 'Subsurface drip sugarcane', 'PC dripline buried 0.3 m deep in 180 m laterals, screen filter and air valve.'),
    SiteExample('gravity', 'Gravity-fed drip', 'A reservoir 40 m above the blocks, no pump, with a pressure reducing valve on the mainline.'),
    SiteExample('pasture', 'Sprinkler-irrigated pasture', 'Three paddocks with impact-sprinkler spray lines at 12 × 18 m, reservoir and pump.'),
    SiteExample('golf', 'Golf hole', 'Tee with sprays, fairway with rotors on a triangular grid and green with rotors around the edge.'),
    SiteExample('sectorPivot', 'Sector pivot with end gun', 'A 250 m pivot sweeping 270° with an end gun, pond, 20 hp pump and gate valve.'),
    SiteExample('linear', 'Linear move', 'A 392 m lateral-move machine travelling 800 m along a canal, with intake and pump.'),
  ],
  faqTitle: 'Frequently asked questions',
  faq: [
    ('What is OpenCADIrrigation?', 'OpenCADIrrigation is a free web application for designing pressurised irrigation systems: a CAD with a hydraulic engine that lays out the network, sizes the pipes, checks pressures and uniformity and produces the bill of materials and reports, from a home garden to a centre pivot.'),
    ('Is OpenCADIrrigation free?', 'Yes. It is free for professional, academic and personal use, with no sign-up.'),
    ('Who is it for?', 'Agricultural and landscape irrigation designers, agronomists and engineers, equipment dealers, teachers and students. The interactive tutorial and 15 ready examples let you start without reading a manual.'),
    ('Do I need to install anything?', 'No. It runs in Chrome, Edge, Firefox and Safari on desktop, tablet and phone, and can be installed as an app (PWA) to open in its own window.'),
    ('Are my projects stored in the cloud?', 'No. Projects are saved in your browser and as .oci.json files you keep wherever you like. Only the online elevation and the base maps reach the internet, when you ask for them.'),
    ('How does it calculate the hydraulics?', 'Friction losses by Hazen-Williams or Darcy-Weisbach, emitters by q = k·Hˣ and the whole network solved by the Global Gradient Algorithm, the method used by EPANET. Pipes are sized by linear programming within the emitter pressure window, and the design also checks uniformity (CU, DU, EU), water hammer and flushing.'),
    ('Does it work with AutoCAD and other CADs?', 'Yes. It imports and exports DXF and DWG (AutoCAD 2000 to 2018), plus Google Earth KML/KMZ, shapefiles, GeoJSON, SVG and PDF.'),
    ('Which languages are available?', 'Twenty, the same as this site (the list is at the foot of the page). The app opens in your computer\'s language and you can switch at any time under View → Language.'),
  ],
  loading: 'Loading the irrigation CAD…',
  slow: 'Loading is taking long. Check the connection or reload the page; the content above can already be read.',
  noScript: 'OpenCADIrrigation needs JavaScript to run. Enable JavaScript in your browser and reload the page.',
  otherLanguages: 'Languages',
  footer: 'Manufacturer catalogues and example projects can be sent as JSON for inclusion in OpenCADIrrigation.',
  subCategory: 'Irrigation CAD',
  screenshotLabel: 'Sized irrigation design with results per zone',
  notFoundTitle: 'Page not found',
  notFoundText: 'That address does not exist on this site. OpenCADIrrigation is a single application; open it from the home page.',
  notFoundHome: 'Go to OpenCADIrrigation',
);

const _es = SiteText(
  title: 'OpenCADIrrigation: CAD de diseño de riego en el navegador',
  description: 'CAD gratuito para diseño de riego en el navegador: goteo, microaspersión, aspersión y pivote central, cálculo hidráulico, lista de materiales y DXF/DWG.',
  keywords: 'diseño de riego, software de riego, CAD riego, riego presurizado, riego por goteo, microaspersión, aspersión, pivote central, dimensionamiento hidráulico, cálculo de tuberías, uniformidad de riego, DXF, DWG, riego de jardines, riego agrícola',
  h1: 'CAD gratuito para diseño de riego presurizado',
  tagline: 'Dibuje, dimensione y documente sistemas de goteo, microaspersión, aspersión y pivote central. Directamente en el navegador, sin instalar nada, con los proyectos guardados en su propio equipo.',
  intro: 'OpenCADIrrigation reúne en un solo lugar el dibujo CAD, la red hidráulica y el cálculo: trace el área, coloque laterales, válvulas y línea principal, pulse F5 y obtenga diámetros, presiones, uniformidad, turnos de operación, lista de materiales e informes listos para imprimir. Disponible en 20 idiomas, según el idioma de su equipo.',
  openApp: 'Abrir la aplicación',
  tutorial: 'Tutorial interactivo',
  seeExamples: 'Ver ejemplos listos',
  featuresTitle: 'Qué hace OpenCADIrrigation',
  features: [
    ('Dibujo CAD completo', 'Líneas, polilíneas, arcos, splines, sombreados, cotas, textos y capas, con referencias a objetos, selección por ventana, pinzamientos y atajos al estilo AutoCAD (L, PL, C, D, ZE…).'),
    ('Red hidráulica', 'Fuentes de agua, bombas, línea principal, válvulas de zona, laterales con emisores, cintas y tuberías de goteo, filtros, reguladores de presión, contadores y nudos; generadores de bloques de laterales y de mallas de aspersores.'),
    ('Motor hidráulico validado', 'Hazen-Williams y Darcy-Weisbach, pérdidas localizadas, emisores q = k·Hˣ, resolución de redes por el Global Gradient Algorithm (como EPANET), curvas de bomba y punto de operación, golpe de ariete y análisis de lavado.'),
    ('Dimensionamiento automático', 'Programación lineal o velocidad máxima, respetando la ventana de presión de los emisores y la clase de las tuberías, equilibrando coste de tubería y energía, con diámetros telescópicos y turnos de operación.'),
    ('Terreno y relieve', 'Curvas de nivel, cotas, modelo digital del terreno por triangulación, elevación descargada de internet a partir de una coordenada, perfiles longitudinales y línea piezométrica sobre el terreno.'),
    ('Informes y materiales', 'Zonas, tuberías, emisores, uniformidad (CU, DU, EU), necesidades de agua por cultivo, programa del controlador y lista de materiales con accesorios; exportación a PDF, Excel, CSV y TXT.'),
    ('Intercambio de archivos', 'Importa DXF, DWG, KML/KMZ, SHP, CSV/XYZ, GeoTIFF e imágenes georreferenciadas; exporta DXF, DWG, PDF con plano, SVG, KML, KMZ y GeoJSON.'),
    ('Catálogos de fabricantes', 'Catálogos de fabricantes en JSON (Netafim, Rivulis, Jain, Toro, Rain Bird, Nelson, Hunter, NaanDanJain, Senninger, Irritec, Bermad, Schneider, Amanco Wavin, Multilit) listos para usar, además de paquetes propios cargados desde archivo o URL.'),
  ],
  howTitle: 'Cómo funciona',
  how: [
    ('Dibuje o importe el área', 'Traiga un DXF, DWG, KML o una imagen satelital, o dibuje la parcela, el jardín o el campo directamente. Añada curvas de nivel o descargue la elevación por coordenada.'),
    ('Arme la red', 'Genere bloques de laterales o mallas de aspersores con un clic, coloque válvulas, bomba y fuente de agua y conéctelo todo con la línea principal.'),
    ('Diseñe y documente', 'Pulse F5: la aplicación dimensiona zonas y línea principal, verifica presiones y velocidades y produce informes, lista de materiales y el plano en PDF.'),
  ],
  examplesTitle: 'Ejemplos listos para abrir',
  examplesIntro: 'Cada proyecto se abre completo y calcula con F5. Úselos para conocer la aplicación o como punto de partida.',
  examples: [
    SiteExample('orchard', 'Huerto', 'Microaspersión en cítricos y goteo en uva, pozo con bomba y filtro, terreno en pendiente.'),
    SiteExample('garden', 'Jardín residencial', 'Difusores emergentes, rotores y goteo en los canteros, conectados a la red pública con contador y antirretorno.'),
    SiteExample('sportsField', 'Campo de fútbol', 'Campo oficial con aspersores de impacto en cinco filas, depósito, bomba y turnos nocturnos.'),
    SiteExample('rowCrop', 'Cultivo con goteo', 'Cuatro parcelas de tomate con cinta de goteo, filtro de malla, bomba y pendiente del 1 %.'),
    SiteExample('pivot', 'Pivote central', 'Pivote de 300 m en maíz alimentado por pozo y bomba, con informe de torres, tramos y boquillas.'),
    SiteExample('greenhouse', 'Invernadero de hortalizas', 'Cuatro túneles con tubería de goteo autocompensante, depósito, bomba pequeña y filtro de discos.'),
    SiteExample('nursery', 'Vivero de plantas', 'Canteros con microaspersores suspendidos en malla de 4 × 4 m, tanque elevado y bomba pequeña.'),
    SiteExample('coffee', 'Cafetal en curvas de nivel', 'Laterales curvos que siguen las curvas de nivel de la ladera, tubería de goteo PC, pozo y bomba.'),
    SiteExample('bananas', 'Platanal', 'Microaspersores autocompensantes a 5 × 5 m, pozo con bomba sumergible y filtro de discos.'),
    SiteExample('sugarcane', 'Caña de azúcar con goteo subterráneo', 'Tubería de goteo PC enterrada a 0,3 m en laterales de 180 m, filtro de malla y ventosa.'),
    SiteExample('gravity', 'Goteo por gravedad', 'Depósito 40 m por encima de las parcelas, sin bomba, con válvula reguladora de presión en la conducción.'),
    SiteExample('pasture', 'Pastura con aspersión', 'Tres potreros con líneas de aspersores de impacto a 12 × 18 m, depósito y bomba.'),
    SiteExample('golf', 'Hoyo de golf', 'Tee con difusores, fairway con rotores en malla triangular y green con rotores en el perímetro.'),
    SiteExample('sectorPivot', 'Pivote sectorial con cañón', 'Pivote de 250 m que gira 270° con cañón final, laguna, bomba de 20 CV y válvula de compuerta.'),
    SiteExample('linear', 'Pivote lineal', 'Lateral de avance frontal de 392 m que recorre 800 m a lo largo de un canal, con toma y bomba.'),
  ],
  faqTitle: 'Preguntas frecuentes',
  faq: [
    ('¿Qué es OpenCADIrrigation?', 'OpenCADIrrigation es una aplicación web gratuita para diseñar sistemas de riego presurizado: un CAD con motor hidráulico que traza la red, dimensiona las tuberías, verifica presiones y uniformidad y produce la lista de materiales y los informes, desde un jardín residencial hasta un pivote central.'),
    ('¿OpenCADIrrigation es gratuito?', 'Sí. Es gratuito para uso profesional, académico y personal, sin registro.'),
    ('¿Para quién es?', 'Para proyectistas de riego agrícola y paisajístico, agrónomos e ingenieros, distribuidores de equipos, profesores y estudiantes. El tutorial interactivo y 15 ejemplos listos permiten empezar sin leer un manual.'),
    ('¿Necesito instalar algo?', 'No. Funciona en Chrome, Edge, Firefox y Safari, en ordenador, tableta y móvil, y puede instalarse como aplicación (PWA) para abrirse en su propia ventana.'),
    ('¿Mis proyectos se guardan en la nube?', 'No. Los proyectos se guardan en su navegador y en archivos .oci.json que usted conserva donde quiera. Solo la elevación en línea y los mapas base acceden a internet, cuando usted lo pide.'),
    ('¿Cómo se hace el cálculo hidráulico?', 'Pérdidas de carga por Hazen-Williams o Darcy-Weisbach, emisores por q = k·Hˣ y toda la red resuelta por el Global Gradient Algorithm, el método de EPANET. Las tuberías se dimensionan por programación lineal dentro de la ventana de presión de los emisores, y el diseño verifica también la uniformidad (CU, DU, EU), el golpe de ariete y el lavado.'),
    ('¿Funciona con AutoCAD y otros CAD?', 'Sí. Importa y exporta DXF y DWG (AutoCAD 2000 a 2018), además de KML/KMZ de Google Earth, shapefile, GeoJSON, SVG y PDF.'),
    ('¿En qué idiomas está disponible?', 'En 20 idiomas, los mismos de este sitio (la lista está al pie de la página). La aplicación se abre en el idioma de su equipo y puede cambiarlo en cualquier momento en Ver → Idioma.'),
  ],
  loading: 'Cargando el CAD de riego…',
  slow: 'La carga está tardando. Compruebe la conexión o recargue la página; el contenido de arriba ya puede leerse.',
  noScript: 'OpenCADIrrigation necesita JavaScript para funcionar. Active JavaScript en el navegador y recargue la página.',
  otherLanguages: 'Idiomas',
  footer: 'Los catálogos de fabricantes y los proyectos de ejemplo pueden enviarse en formato JSON para incluirse en OpenCADIrrigation.',
  subCategory: 'CAD para riego',
  screenshotLabel: 'Diseño de riego dimensionado con resultados por zona',
  notFoundTitle: 'Página no encontrada',
  notFoundText: 'Esa dirección no existe en este sitio. OpenCADIrrigation es una única aplicación; ábrala desde la página de inicio.',
  notFoundHome: 'Ir a OpenCADIrrigation',
);

const _siteTexts = {
  'id': _id,
  'de': _de,
  'en': _en,
  'es': _es,
  'fr': _fr,
  'ha': _ha,
  'sw': _sw,
  'pt': _pt,
  'vi': _vi,
  'tr': _tr,
  'ru': _ru,
  'ar': _ar,
  'ur': _ur,
  'hi': _hi,
  'mr': _mr,
  'bn': _bn,
  'pa': _pa,
  'te': _te,
  'zh': _zh,
  'ja': _ja,
};

SiteText siteText(String code) => _siteTexts[code]!;

String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

String _hreflangLinks() => [
  for (final l in siteLanguages) '  <link rel="alternate" hreflang="${l.tag}" href="${l.url}">',
  '  <link rel="alternate" hreflang="x-default" href="${siteLang('en').url}">',
].join('\n');

/// What the application is about, as entities search engines and language
/// models already know: name, Wikipedia article, Wikidata item.
const _subjects = [
  ('Irrigation', 'Irrigation', 'Q11453'),
  ('Drip irrigation', 'Drip_irrigation', 'Q746694'),
  ('Micro-irrigation', 'Micro-irrigation', 'Q6692750'),
  ('Irrigation sprinkler', 'Irrigation_sprinkler', 'Q998539'),
  ('Center-pivot irrigation', 'Center-pivot_irrigation', 'Q2744831'),
  ('Computer-aided design', 'Computer-aided_design', 'Q184793'),
];

/// JSON-LD graph of a page: organisation, web site, this web page, a
/// one-level breadcrumb, the application, its FAQ, how it works and the
/// example gallery, all in the language of the page.
String jsonLd(SiteLang lang) {
  final t = siteText(lang.code);
  final graph = [
    {
      '@type': 'Organization',
      '@id': '$siteUrl#org',
      'name': 'OpenCADIrrigation',
      'url': siteUrl,
      'logo': {'@type': 'ImageObject', 'url': '${siteUrl}brand/logo-square.png', 'width': 1254, 'height': 1254},
    },
    {
      '@type': 'WebSite',
      '@id': '$siteUrl#site',
      'url': siteUrl,
      'name': 'OpenCADIrrigation',
      'description': t.description,
      'inLanguage': [for (final l in siteLanguages) l.tag],
      'publisher': {'@id': '$siteUrl#org'},
    },
    {
      '@type': 'WebPage',
      '@id': '${lang.url}#page',
      'url': lang.url,
      'name': t.title,
      'description': t.description,
      'inLanguage': lang.tag,
      'isPartOf': {'@id': '$siteUrl#site'},
      'about': {'@id': '$siteUrl#app'},
      'mainEntity': {'@id': '$siteUrl#app'},
      'hasPart': [
        {'@id': '${lang.url}#faq'},
        {'@id': '${lang.url}#how'},
        {'@id': '${lang.url}#examples'},
      ],
      'primaryImageOfPage': {'@type': 'ImageObject', 'url': '${siteUrl}og-image.png', 'width': 1200, 'height': 630},
      'dateModified': siteLastMod,
      'breadcrumb': {'@id': '${lang.url}#breadcrumb'},
    },
    {
      '@type': 'BreadcrumbList',
      '@id': '${lang.url}#breadcrumb',
      'itemListElement': [
        {'@type': 'ListItem', 'position': 1, 'name': 'OpenCADIrrigation', 'item': lang.url},
      ],
    },
    {
      '@type': 'WebApplication',
      '@id': '$siteUrl#app',
      'name': 'OpenCADIrrigation',
      'alternateName': 'OpenCAD Irrigation',
      'url': lang.url,
      'installUrl': lang.url,
      'image': '${siteUrl}og-image.png',
      'screenshot': {'@type': 'ImageObject', 'url': '${siteUrl}screenshots/design-1440x900.png', 'width': 1440, 'height': 900, 'caption': t.screenshotLabel},
      'description': t.description,
      'abstract': t.faq.first.$2,
      'applicationCategory': 'DesignApplication',
      'applicationSubCategory': t.subCategory,
      'operatingSystem': 'Web browser (Chrome, Edge, Firefox, Safari)',
      'browserRequirements': 'Requires JavaScript and WebAssembly',
      'availableOnDevice': 'Desktop, tablet, phone',
      'softwareVersion': appVersion,
      'dateModified': siteLastMod,
      'softwareHelp': {'@type': 'CreativeWork', 'url': '${lang.url}?tutorial=1', 'name': t.tutorial},
      'isAccessibleForFree': true,
      'offers': {'@type': 'Offer', 'price': '0', 'priceCurrency': 'USD', 'availability': 'https://schema.org/InStock'},
      'inLanguage': [for (final l in siteLanguages) l.tag],
      'keywords': t.keywords,
      'featureList': [for (final (name, text) in t.features) '$name: $text'],
      'about': [
        for (final (name, article, wikidata) in _subjects)
          {'@type': 'Thing', 'name': name, 'sameAs': ['https://en.wikipedia.org/wiki/$article', 'https://www.wikidata.org/wiki/$wikidata']},
      ],
      'author': {'@id': '$siteUrl#org'},
      'publisher': {'@id': '$siteUrl#org'},
    },
    {
      '@type': 'FAQPage',
      '@id': '${lang.url}#faq',
      'name': t.faqTitle,
      'inLanguage': lang.tag,
      'isPartOf': {'@id': '${lang.url}#page'},
      'mainEntity': [
        for (final (q, a) in t.faq)
          {
            '@type': 'Question',
            'name': q,
            'acceptedAnswer': {'@type': 'Answer', 'text': a},
          },
      ],
    },
    {
      '@type': 'HowTo',
      '@id': '${lang.url}#how',
      'name': t.howTitle,
      'description': t.intro,
      'inLanguage': lang.tag,
      'tool': {'@id': '$siteUrl#app'},
      'step': [
        for (final (i, (name, text)) in t.how.indexed) {'@type': 'HowToStep', 'position': i + 1, 'name': name, 'text': text},
      ],
    },
    {
      '@type': 'ItemList',
      '@id': '${lang.url}#examples',
      'name': t.examplesTitle,
      'description': t.examplesIntro,
      'numberOfItems': t.examples.length,
      'itemListElement': [
        for (final (i, ex) in t.examples.indexed)
          {
            '@type': 'ListItem',
            'position': i + 1,
            'item': {'@type': 'CreativeWork', 'name': ex.title, 'description': ex.text, 'url': '${lang.url}?example=${ex.id}', 'inLanguage': lang.tag},
          },
      ],
    },
  ];
  return const JsonEncoder.withIndent('  ').convert({'@context': 'https://schema.org', '@graph': graph});
}

const _style = '''
    html, body { margin: 0; min-height: 100%; background: #14171B; color: #CFD8DC; font: 16px/1.55 -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }
    #oci-landing { position: relative; z-index: 2147483000; background: #14171B; }
    #oci-landing[hidden] { display: none; }
    #oci-landing a { color: #64B5F6; }
    #oci-landing .wrap { max-width: 980px; margin: 0 auto; padding: 28px 20px 40px; }
    #oci-landing header { text-align: center; padding-top: 12px; }
    #oci-landing header img { width: min(520px, 78vw); height: auto; filter: drop-shadow(0 6px 24px rgba(0,0,0,.45)); }
    #oci-landing h1 { font-size: clamp(1.5rem, 3.4vw, 2.2rem); line-height: 1.2; color: #ECEFF1; margin: 22px 0 10px; }
    #oci-landing h2 { font-size: 1.3rem; color: #ECEFF1; margin: 40px 0 12px; }
    #oci-landing h3 { font-size: 1.02rem; color: #ECEFF1; margin: 0 0 4px; }
    #oci-landing p { margin: 8px 0; }
    #oci-landing .tagline { font-size: 1.08rem; color: #B0BEC5; max-width: 760px; margin: 0 auto 14px; }
    #oci-landing .cta { display: flex; flex-wrap: wrap; gap: 10px; justify-content: center; margin: 18px 0 6px; }
    #oci-landing .cta a { display: inline-block; padding: 10px 18px; border-radius: 8px; text-decoration: none; font-weight: 600; background: #1E2A38; color: #E3F2FD; border: 1px solid #2E4053; }
    #oci-landing .cta a.primary { background: linear-gradient(90deg, #0D47A1, #1976D2); border-color: #1976D2; color: #fff; }
    #oci-landing .bar { width: min(280px, 60vw); height: 3px; margin: 18px auto 6px; background: #263238; border-radius: 2px; overflow: hidden; }
    #oci-landing .bar span { display: block; width: 40%; height: 100%; background: linear-gradient(90deg, #0D47A1, #29B6F6); border-radius: 2px; animation: oci-slide 1.2s ease-in-out infinite; }
    @keyframes oci-slide { 0% { transform: translateX(-100%); } 100% { transform: translateX(260%); } }
    #oci-landing .status { text-align: center; color: #90A4AE; font-size: .95rem; margin: 0; }
    #oci-landing .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 14px; margin: 0; padding: 0; list-style: none; }
    #oci-landing .grid li { background: #1B1F24; border: 1px solid #263238; border-radius: 10px; padding: 14px 16px; }
    #oci-landing ol.steps { padding-inline-start: 1.3em; }
    #oci-landing ol.steps li { margin: 8px 0; }
    #oci-landing dl dt { font-weight: 600; color: #ECEFF1; margin-top: 14px; }
    #oci-landing dl dd { margin: 4px 0 0; }
    #oci-landing footer { margin-top: 44px; padding-top: 16px; border-top: 1px solid #263238; color: #90A4AE; font-size: .92rem; }
    #oci-landing footer nav { line-height: 1.9; }
    #oci-landing footer .meta { font-size: .85rem; color: #78909C; }
    #oci-noscript { background: #B71C1C; color: #fff; padding: 12px 20px; text-align: center; font: 15px -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }
''';

/// The entry page of [lang]: the Flutter app plus the crawlable landing.
String renderIndex(SiteLang lang) {
  final t = siteText(lang.code);
  final base = lang.isRoot ? r'$FLUTTER_BASE_HREF' : '/';
  final b = StringBuffer();
  b.writeln('<!DOCTYPE html>');
  b.writeln('<html lang="${lang.tag}">');
  b.writeln('<head>');
  if (lang.isRoot) {
    b.writeln('  <!-- The base href placeholder is replaced by flutter build (--base-href); /pt/, /es/, /de/, … are copies of this page rooted at "/". -->');
  } else {
    b.writeln('  <!-- Generated by tool/gen_site.dart from tool/site.dart; do not edit by hand. -->');
  }
  b.writeln('  <base href="$base">');
  b.writeln('''
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">

  <title>${_esc(t.title)}</title>
  <meta name="description" content="${_esc(t.description)}">
  <meta name="keywords" content="${_esc(t.keywords)}">
  <meta name="author" content="OpenCADIrrigation">
  <meta name="application-name" content="OpenCADIrrigation">
  <meta name="robots" content="index, follow, max-image-preview:large, max-snippet:-1, max-video-preview:-1">
  <meta name="googlebot" content="index, follow, max-image-preview:large, max-snippet:-1">
  <meta name="applicable-device" content="pc,mobile">
  <meta name="format-detection" content="telephone=no">
  <meta name="theme-color" content="#0D47A1">
  <meta name="color-scheme" content="dark">
  <link rel="canonical" href="${lang.url}">
${_hreflangLinks()}
  <link rel="alternate" type="text/markdown" href="${siteUrl}llms.txt" title="OpenCADIrrigation for language models (llms.txt)">

  <!-- Open Graph / Facebook / WhatsApp / LinkedIn -->
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="OpenCADIrrigation">
  <meta property="og:url" content="${lang.url}">
  <meta property="og:title" content="${_esc(t.title)}">
  <meta property="og:description" content="${_esc(t.description)}">
  <meta property="og:image" content="${siteUrl}og-image.png">
  <meta property="og:image:secure_url" content="${siteUrl}og-image.png">
  <meta property="og:image:type" content="image/png">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:image:alt" content="${_esc(t.h1)}">
  <meta property="og:locale" content="${lang.ogLocale}">''');
  for (final l in siteLanguages) {
    if (l.code != lang.code) b.writeln('  <meta property="og:locale:alternate" content="${l.ogLocale}">');
  }
  b.writeln('''
  <!-- Twitter / X -->
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="${_esc(t.title)}">
  <meta name="twitter:description" content="${_esc(t.description)}">
  <meta name="twitter:image" content="${siteUrl}og-image.png">
  <meta name="twitter:image:alt" content="${_esc(t.h1)}">

  <!-- Icons and app manifest -->
  <link rel="icon" href="favicon.ico" sizes="any">
  <link rel="icon" type="image/png" sizes="16x16" href="favicon-16.png">
  <link rel="icon" type="image/png" sizes="32x32" href="favicon-32.png">
  <link rel="icon" type="image/png" sizes="64x64" href="favicon.png">
  <link rel="apple-touch-icon" sizes="180x180" href="apple-touch-icon.png">
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
  <meta name="apple-mobile-web-app-title" content="OpenCADIrrigation">
  <meta name="msapplication-TileColor" content="#0D47A1">
  <meta name="msapplication-TileImage" content="brand/logo-tile-512.png">
  <link rel="manifest" href="manifest.json">

  <!-- Faster first paint: the engine comes from gstatic, the logo is the first image -->
  <link rel="preconnect" href="https://www.gstatic.com" crossorigin>
  <link rel="dns-prefetch" href="https://www.gstatic.com">
  <link rel="preload" as="image" href="brand/logo-horizontal-1000.png">

  <script type="application/ld+json">
${jsonLd(lang)}
  </script>

$_analytics

  <style>$_style  </style>
</head>
<body>
  <noscript><div id="oci-noscript"${lang.dirAttr}>${_esc(t.noScript)}</div></noscript>
  <!-- Readable content: shown while the app loads, hidden (kept in the page) on Flutter's first frame. -->
  <main id="oci-landing"${lang.dirAttr}>
    <div class="wrap">
      <header>
        <img src="brand/logo-horizontal-1000.png" alt="OpenCADIrrigation" width="1000" height="336" fetchpriority="high">
        <h1>${_esc(t.h1)}</h1>
        <p class="tagline">${_esc(t.tagline)}</p>
        <nav class="cta" aria-label="${_esc(t.openApp)}">
          <a class="primary" href="${lang.url}">${_esc(t.openApp)}</a>
          <a href="${lang.url}?tutorial=1">${_esc(t.tutorial)}</a>
          <a href="#exemplos">${_esc(t.seeExamples)}</a>
        </nav>
        <div class="bar" aria-hidden="true"><span></span></div>
        <p class="status" id="oci-status" role="status" aria-live="polite">${_esc(t.loading)}</p>
      </header>
      <p>${_esc(t.intro)}</p>

      <section aria-labelledby="oci-features">
        <h2 id="oci-features">${_esc(t.featuresTitle)}</h2>
        <ul class="grid">''');
  for (final (name, text) in t.features) {
    b.writeln('          <li><h3>${_esc(name)}</h3><p>${_esc(text)}</p></li>');
  }
  b.writeln('''        </ul>
      </section>

      <section aria-labelledby="oci-how">
        <h2 id="oci-how">${_esc(t.howTitle)}</h2>
        <ol class="steps">''');
  for (final (name, text) in t.how) {
    b.writeln('          <li><strong>${_esc(name)}.</strong> ${_esc(text)}</li>');
  }
  b.writeln('''        </ol>
      </section>

      <section id="exemplos" aria-labelledby="oci-examples">
        <h2 id="oci-examples">${_esc(t.examplesTitle)}</h2>
        <p>${_esc(t.examplesIntro)}</p>
        <ul class="grid">''');
  for (final ex in t.examples) {
    b.writeln('          <li><h3><a href="${lang.url}?example=${ex.id}">${_esc(ex.title)}</a></h3><p>${_esc(ex.text)}</p></li>');
  }
  b.writeln('''        </ul>
      </section>

      <section aria-labelledby="oci-faq">
        <h2 id="oci-faq">${_esc(t.faqTitle)}</h2>
        <dl>''');
  for (final (q, a) in t.faq) {
    b.writeln('          <dt>${_esc(q)}</dt>');
    b.writeln('          <dd>${_esc(a)}</dd>');
  }
  b.writeln('''        </dl>
      </section>

      <footer>
        <nav aria-label="${_esc(t.otherLanguages)}">${_esc(t.otherLanguages)}: ${[for (final l in siteLanguages) l.code == lang.code ? '<strong lang="${l.tag}" dir="${l.dir}">${languageNames[l.code]}</strong>' : '<a href="${l.url}" hreflang="${l.tag}" lang="${l.tag}" dir="${l.dir}">${languageNames[l.code]}</a>'].join(' · ')}</nav>
        <p>${_esc(t.footer)}</p>
        <p class="meta">OpenCADIrrigation $appVersion · <time datetime="$siteLastMod">$siteLastMod</time></p>
      </footer>
    </div>
  </main>
  <script>
    (function () {
      var landing = document.getElementById('oci-landing');
      var status = document.getElementById('oci-status');
      function hide() { if (landing) landing.setAttribute('hidden', ''); }
      window.addEventListener('flutter-first-frame', hide);
      setTimeout(function () {
        if (landing && !landing.hasAttribute('hidden') && status) status.textContent = ${jsonEncode(t.slow)};
      }, 30000);
    })();
  </script>
  <script src="flutter_bootstrap.js" async></script>
</body>
</html>''');
  return b.toString();
}

/// sitemap.xml with the entry pages, their hreflang alternates and the
/// images they show (for image search).
String renderSitemap() {
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml" xmlns:image="http://www.google.com/schemas/sitemap-image/1.1">');
  for (final l in siteLanguages) {
    b.writeln('  <url>');
    b.writeln('    <loc>${l.url}</loc>');
    b.writeln('    <lastmod>$siteLastMod</lastmod>');
    b.writeln('    <changefreq>weekly</changefreq>');
    b.writeln('    <priority>${l.isRoot ? '1.0' : '0.9'}</priority>');
    for (final a in siteLanguages) {
      b.writeln('    <xhtml:link rel="alternate" hreflang="${a.tag}" href="${a.url}"/>');
    }
    b.writeln('    <xhtml:link rel="alternate" hreflang="x-default" href="${siteLang('en').url}"/>');
    for (final image in ['screenshots/design-1440x900.png', 'og-image.png', 'brand/logo-horizontal-1000.png']) {
      b.writeln('    <image:image><image:loc>$siteUrl$image</image:loc></image:image>');
    }
    b.writeln('  </url>');
  }
  b.writeln('</urlset>');
  return b.toString();
}

/// Crawlers of search engines and of AI assistants, by the user-agent token
/// each company documents: those that index or answer live questions and
/// those that collect training data. All are allowed on the whole site; the
/// named groups make the choice explicit and survive a stricter `*` later.
const aiCrawlers = [
  // OpenAI: ChatGPT search, live fetches, training
  'OAI-SearchBot', 'ChatGPT-User', 'GPTBot',
  // Anthropic: Claude search, live fetches, training
  'Claude-SearchBot', 'Claude-User', 'ClaudeBot', 'anthropic-ai',
  // Perplexity
  'PerplexityBot', 'Perplexity-User',
  // Google Gemini and Vertex AI grounding, Apple Intelligence
  'Google-Extended', 'Applebot', 'Applebot-Extended',
  // Microsoft Copilot answers from Bing's index
  'bingbot',
  // Meta AI, Amazon (Alexa, Rufus), DuckDuckGo assist, Mistral, Cohere, You.com
  'meta-externalagent', 'meta-externalfetcher', 'Amazonbot', 'DuckAssistBot', 'MistralAI-User', 'cohere-ai', 'YouBot',
  // Open datasets many models are trained on
  'CCBot', 'AI2Bot', 'Diffbot',
];

/// robots.txt: everything is public, for every crawler.
String renderRobots() {
  final b = StringBuffer()
    ..writeln('# OpenCADIrrigation — $siteUrl')
    ..writeln('# A single application in ${siteLanguages.length} languages (/ in English, the others under their code: /pt/, /es/, /de/, /zh/, …); everything is public.')
    ..writeln('# Language models: a summary is at ${siteUrl}llms.txt and the complete reference at ${siteUrl}llms-full.txt.')
    ..writeln()
    ..writeln('User-agent: *')
    ..writeln('Allow: /')
    ..writeln()
    ..writeln('# Search and AI assistants are welcome to read, cite and learn from the site.');
  for (final agent in aiCrawlers) {
    b.writeln('User-agent: $agent');
  }
  b
    ..writeln('Allow: /')
    ..writeln()
    ..writeln('Sitemap: ${siteUrl}sitemap.xml');
  return b.toString();
}

/// humans.txt: who and what is behind the site.
String renderHumans() {
  final languages = [for (final l in siteLanguages) '${languageNames[l.code]} (/${l.path})'].join(', ');
  return '''/* TEAM */
Project: OpenCADIrrigation
Site: $siteUrl

/* SITE */
Last update: $siteLastMod
Version: $appVersion
Standards: HTML5, CSS3, JavaScript, WebAssembly (Flutter web)
Languages: $languages
Pages: generated by tool/gen_site.dart
For language models: ${siteUrl}llms.txt, ${siteUrl}llms-full.txt
''';
}

/// 404 page (GitHub Pages serves it for unknown paths): not indexed. It
/// shows the message in English, or in the first browser language the site
/// speaks, and links to every entry page.
String render404() {
  final b = StringBuffer()..writeln('''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="robots" content="noindex, follow">
  <title>404 — OpenCADIrrigation</title>
  <link rel="icon" href="/favicon.ico" sizes="any">
  <style>
    html, body { margin: 0; min-height: 100%; background: #14171B; color: #CFD8DC; font: 16px/1.55 -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }
    main { max-width: 720px; margin: 0 auto; padding: 48px 20px; text-align: center; }
    img { width: min(420px, 80vw); height: auto; }
    h1 { color: #ECEFF1; font-size: 1.6rem; }
    a { color: #64B5F6; }
    .cta { display: inline-block; margin: 8px; padding: 10px 18px; border-radius: 8px; text-decoration: none; font-weight: 600; background: linear-gradient(90deg, #0D47A1, #1976D2); color: #fff; }
    section { margin-top: 28px; }
    section[hidden] { display: none; }
    nav { margin-top: 36px; padding-top: 16px; border-top: 1px solid #263238; color: #90A4AE; font-size: .92rem; line-height: 1.9; }
  </style>
</head>
<body>
  <main>
    <img src="/brand/logo-horizontal-1000.png" alt="OpenCADIrrigation" width="1000" height="336">''');
  for (final l in siteLanguages) {
    final t = siteText(l.code);
    b.writeln('    <section lang="${l.tag}"${l.dirAttr} data-lang="${l.code}"${l.code == 'en' ? '' : ' hidden'}>');
    b.writeln('      <h1>${_esc(t.notFoundTitle)}</h1>');
    b.writeln('      <p>${_esc(t.notFoundText)}</p>');
    b.writeln('      <a class="cta" href="${l.url}">${_esc(t.notFoundHome)}</a>');
    b.writeln('    </section>');
  }
  b.writeln('    <nav aria-label="Languages">${[for (final l in siteLanguages) '<a href="${l.url}" hreflang="${l.tag}" lang="${l.tag}" dir="${l.dir}">${languageNames[l.code]}</a>'].join(' · ')}</nav>');
  b.writeln('''  </main>
  <script>
    (function () {
      var tags = navigator.languages || [navigator.language || ''];
      for (var i = 0; i < tags.length; i++) {
        var code = String(tags[i]).split(/[-_]/)[0].toLowerCase();
        var s = document.querySelector('section[data-lang="' + code + '"]');
        if (!s) continue;
        if (code !== 'en') {
          document.querySelector('section[data-lang="en"]').hidden = true;
          s.hidden = false;
          document.documentElement.lang = s.lang;
        }
        return;
      }
    })();
  </script>
</body>
</html>''');
  return b.toString();
}

/// Google Analytics (gtag.js), on every entry page.
const _analytics = '''  <!-- Google tag (gtag.js) -->
  <script async src="https://www.googletagmanager.com/gtag/js?id=$analyticsId"></script>
  <script>
    window.dataLayer = window.dataLayer || [];
    function gtag(){dataLayer.push(arguments);}
    gtag('js', new Date());
    gtag('config', '$analyticsId');
  </script>''';

/// Page kept at the old English address `/en/`, which is now the site root:
/// it is not indexed and sends the visitor (and any `?example=`, `?tutorial=`
/// query it carries) to `/`.
String renderLegacyEnRedirect() {
  final home = siteLang('en').url;
  return '''<!DOCTYPE html>
<html lang="en">
<head>
  <!-- Generated by tool/gen_site.dart from tool/site.dart; do not edit by hand. -->
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="robots" content="noindex, follow">
  <title>OpenCADIrrigation</title>
  <link rel="icon" href="/favicon.ico" sizes="any">
  <meta http-equiv="refresh" content="0; url=/">
  <script>location.replace('/' + location.search + location.hash);</script>
  <style>
    html, body { margin: 0; min-height: 100%; background: #14171B; color: #CFD8DC; font: 16px/1.55 -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }
    main { max-width: 720px; margin: 0 auto; padding: 48px 20px; text-align: center; }
    a { color: #64B5F6; }
  </style>
</head>
<body>
  <main>
    <p>OpenCADIrrigation in English is now at <a href="$home">$home</a>.</p>
  </main>
</body>
</html>''';
}

/// Every generated file: path inside `web/` → content.
Map<String, String> renderSite() => {
  for (final l in siteLanguages) l.file: renderIndex(l),
  'en/index.html': renderLegacyEnRedirect(),
  'sitemap.xml': renderSitemap(),
  '404.html': render404(),
  'robots.txt': renderRobots(),
  'humans.txt': renderHumans(),
  'llms.txt': renderLlmsTxt(),
  'llms-full.txt': renderLlmsFullTxt(),
  '$indexNowKey.txt': indexNowKey,
};
