/// The public web pages of opencadirrigation.com, rendered from one template
/// in every interface language of the app: English at the root (`/`, the
/// Flutter entry page), the others under their language code (`/pt/`,
/// `/es/`, `/de/`, `/zh/`, …), plus the sitemap and the 404 page. The
/// Portuguese, English and Spanish texts are below; the other languages live
/// in `tool/site/<code>.dart`.
///
/// Search engines cannot read what Flutter paints on its canvas, so every
/// entry page carries the same content as real HTML: heading, description,
/// the AI assistant section, feature list, ready examples and FAQ. The app
/// (several megabytes) is only
/// fetched when the visitor asks for it — the page's buttons and example
/// links, an app address such as `?example=`, `?tutorial=1` or `?ai=1`, the installed
/// PWA — or has already used it in this browser; a first visit (and a
/// crawler, and PageSpeed) gets the light page alone. The page is hidden
/// (kept in the DOM) on Flutter's first frame. Each page declares its
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
import 'dart:io';

import 'package:opencadirrigation/app/i18n.dart' show languageNames, languageTag, rtlLanguages, supportedLanguages;
import 'package:opencadirrigation/app/version.dart' show appRepositoryUrl, appVersion;

import 'site_manual.dart';

part 'site/ar.dart';
part 'site/bn.dart';
part 'site/de.dart';
part 'site/fr.dart';
part 'site/ha.dart';
part 'site/hi.dart';
part 'site/id.dart';
part 'site/ja.dart';
part 'site/legal.dart';
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

/// Google Analytics measurement id of the site, written into the pages for
/// `site.js`, which loads the statistics, with their cookies, on every page
/// and in the app (Cookie settings, at the foot of the pages, turns them off
/// in a browser). A fork sets its own:
/// `OCI_ANALYTICS_ID=G-… dart run tool/gen_site.dart`; an empty one leaves
/// the statistics and their notice out of the pages.
final analyticsId = Platform.environment['OCI_ANALYTICS_ID'] ?? 'G-3M0P4T8V2T';
const siteLastMod = '2026-11-02';

/// The Firebase project that serves the site: its default addresses
/// (`<id>.web.app`, `<id>.firebaseapp.com`) send a new visitor to [siteUrl].
const firebaseProjectId = 'opencadirrigation';

/// The plain-HTTP addresses of this computer a page served over HTTPS may
/// still reach (lib/app/canvas/basemap.dart accepts them for map tiles).
const _localServers = 'http://localhost:* http://127.0.0.1:*';

/// Content Security Policy of the entry and legal pages, as a meta element
/// so that it travels with the pages (the hosting configuration,
/// [renderHostingConfig], adds what a meta element cannot carry). Scripts
/// come only from the site (no inline script: the page logic is `site.js`)
/// and from Google's tag manager (the visit statistics); WebAssembly is compiled for CanvasKit; images, map tiles, the
/// elevation, climate and AI services and the catalogues by URL are
/// fetched from any HTTPS address the user picks, and map tiles also from a
/// server of one's own on this computer (http://localhost, the one plain
/// address a browser loads into an HTTPS page); the fonts, the fallback
/// fonts of the engine included (tool/site_fonts.dart), come from the site
/// itself; no plugins, frames or foreign base address.
const contentSecurityPolicy =
    "default-src 'self'; script-src 'self' 'wasm-unsafe-eval' https://*.googletagmanager.com; style-src 'self' 'unsafe-inline'; "
    "img-src 'self' data: blob: https: $_localServers; font-src 'self' data:; connect-src 'self' https: data: blob: $_localServers; "
    "worker-src 'self' blob:; child-src 'self' blob:; manifest-src 'self'; media-src 'self' data: blob:; frame-src 'none'; "
    "object-src 'none'; base-uri 'self'; form-action 'self'";

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
final siteLanguages = [for (final code in supportedLanguages) SiteLang(code, languageTag(code), _ogLocales[code]!, code == 'en' ? '' : '$code/')];

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
    required this.aiTitle,
    required this.aiIntro,
    required this.aiPoints,
    required this.aiCta,
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
    required this.sourceCode,
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

  /// The AI assistant section, first on the page: heading, paragraph, what
  /// it does as `(title, text)` cards, and the button that opens the app
  /// with the assistant beside the drawing (`?ai=1`).
  final String aiTitle;
  final String aiIntro;
  final List<(String, String)> aiPoints;
  final String aiCta;
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

  /// Label of the footer link to the source code on GitHub (the app's
  /// `about.repo`).
  final String sourceCode;
  final String subCategory;
  final String screenshotLabel;
  final String notFoundTitle;
  final String notFoundText;
  final String notFoundHome;
}

/// Answer of the FAQ "Are my projects stored in the cloud?" in English. The
/// pages of the languages written in tool/site/<code>.dart use it as well
/// until its translation arrives (the earlier answer promised that the
/// internet was reached only on request, which the fonts and the visit
/// statistics contradicted).
const faqCloudAnswerEn =
    'No. Projects are saved in your browser and as .oci.json files you keep wherever you like; a share link carries the project inside the address itself, so nothing is uploaded, and OpenCADIrrigation has no server that could keep a copy. The fonts of every script and symbol come from this site itself. The browser does reach other services: base maps, online elevation and climate, address search, catalogues loaded by URL and, if you use it, the AI assistant (only the provider you chose, Anthropic or OpenAI) go to their services when you use them; and the site and the app count visits with Google Analytics, which uses cookies (Cookie settings, at the foot of the pages, turns it off). The privacy policy lists each service and what it receives.';

const _pt = SiteText(
  title: 'OpenCADIrrigation: software grátis de projeto de irrigação com IA',
  description: 'Software grátis e de código aberto para projeto de irrigação com assistente de IA que distribui aspersores e gotejamento, traça tubos e dimensiona o sistema.',
  keywords: 'projeto de irrigação com IA, inteligência artificial projeto de irrigação, software de projeto de irrigação, projeto de irrigação, software de irrigação grátis, software de irrigação de código aberto, projeto automático de irrigação, distribuição automática de aspersores, CAD irrigação, software de irrigação, gotejamento, microaspersão, aspersão, pivô central, dimensionamento hidráulico, dimensionamento de tubulação, uniformidade de irrigação, DXF, DWG, irrigação de jardim, irrigação agrícola',
  h1: 'Software gratuito e de código aberto para projeto de irrigação com assistente de IA',
  tagline: 'Descreva o talhão, o jardim ou o campo e deixe o assistente de IA distribuir os aspersores e o gotejamento, traçar os tubos e dimensionar o sistema; ou desenhe você mesmo com as ferramentas automáticas. Gotejamento, microaspersão, aspersão e pivô central, direto no navegador, sem instalar nada, com os projetos guardados no seu computador.',
  intro: 'O OpenCADIrrigation reúne num só lugar o desenho CAD, a rede hidráulica, o cálculo e um assistente de IA. Trace a área, ou deixe a IA localizar o terreno na imagem de satélite; lance laterais, válvulas e linha principal à mão, com os geradores de um clique ou pedindo à IA; aperte F5 e receba diâmetros, pressões, uniformidade, turnos de operação, lista de materiais e relatórios prontos para imprimir. O assistente usa modelos Claude (Anthropic) ou GPT (OpenAI) com a sua própria chave de API, direto do navegador. Funciona em 20 idiomas e segue o idioma do seu computador.',
  openApp: 'Abrir o app',
  tutorial: 'Tutorial interativo',
  seeExamples: 'Ver exemplos prontos',
  aiTitle: 'Um assistente de IA que desenha e projeta com você',
  aiIntro: 'Abra o painel de IA ao lado do desenho e peça com as suas palavras. O assistente lê o projeto, olha a imagem de satélite e o terreno e trabalha com as mesmas ferramentas dos menus, de modo que o que ele desenha é um projeto de verdade: itens, tubos, válvulas, zonas e resultados, não uma figura. Cada alteração espera a sua aprovação, ou é aplicada automaticamente se você preferir, e pode ser desfeita com um clique.',
  aiPoints: [
    (
      'Desenha e projeta automaticamente',
      'Distribui aspersores e linhas de gotejamento, divide talhões em blocos, ajusta pivôs, traça tubos e válvulas, posiciona a bomba e a fonte de água, roda o dimensionamento, corrige os avisos e otimiza o custo, e depois escreve o memorial técnico e o orçamento.',
    ),
    (
      'Enxerga o terreno',
      'Localiza o terreno por um endereço, olha a imagem de satélite de um projeto georreferenciado e o relevo (sombreado, curvas de nível, declividade, perfis), lê os desenhos e arquivos SIG que você anexar e inclui itens de catálogo a partir de uma folha de dados em PDF. Contorna sozinho os talhões na imagem, segue os pontos e as linhas que você marcar no mapa e fixa no desenho as fotos de campo com GPS, no lugar onde foram tiradas.',
    ),
    (
      'Explica e verifica',
      'Responde perguntas sobre o projeto e os resultados, explica cada mensagem do dimensionamento e como corrigi-la, roda as análises e mantém no projeto uma lista de tarefas e notas das suas decisões. Quando você pede, revisa o projeto inteiro sem alterar nada e olha a prancha antes de você exportá-la.',
    ),
    (
      'Sua chave, seu controle',
      'Modelos Claude (Anthropic) ou GPT (OpenAI) nos níveis topo, intermediário e rápido, com a sua própria chave de API, chamados direto do navegador, sem servidor no meio. Modos somente leitura, planejar antes, perguntar antes de cada alteração ou automático, limite de passos e de gasto por tarefa, desfazer para cada resposta e nada enviado antes de você clicar em Enviar.',
    ),
  ],
  aiCta: 'Abrir o assistente de IA',
  featuresTitle: 'O que o OpenCADIrrigation faz',
  features: [
    (
      'Assistente de IA',
      'Opcional: pergunte à IA sobre o projeto ou deixe que ela desenhe e projete por você. Ela distribui aspersores e gotejamento, divide talhões, traça tubos, roda o dimensionamento e as ferramentas automáticas, olhando a imagem de satélite e o terreno, com modelos Claude (Anthropic) ou GPT (OpenAI) e a sua própria chave de API, direto do navegador, sem servidor no meio. Nada é enviado antes de você clicar em Enviar, e cada alteração espera a sua aprovação (ou é aplicada automaticamente, se você preferir) e pode ser desfeita.',
    ),
    (
      'Projeto e dimensionamento automáticos',
      'Blocos de laterais e grades de aspersores com um clique, distribuição de aspersores com precipitação equilibrada, divisão em zonas pela vazão, traçado de tubos e válvulas, divisão de talhões em blocos, ajuste de pivô e detecção de vegetação em imagens aéreas; tubos dimensionados por programação linear dentro da janela de pressão dos emissores e da classe de pressão dos tubos, com balanço entre custo de tubulação e energia.',
    ),
    (
      'Desenho CAD completo',
      'Linhas, polilinhas, arcos, splines, hachuras, cotas, textos, camadas e blocos, com coordenadas digitadas, snaps, rastreamento polar, grips, nuvens de revisão e os atalhos de comando dos programas de CAD (L, PL, C, D, ZE…).',
    ),
    (
      'Rede hidráulica',
      'Fontes de água, bombas de rotação fixa ou variável, linha principal, válvulas de zona, redutoras e sustentadoras de pressão e limitadoras de vazão, aspersores com válvula incorporada, laterais com emissores, fitas gotejadoras, filtros e hidrômetros, além de pivôs centrais e lineares com seu pacote de aspersores, autopropelidos e irrigação por superfície.',
    ),
    (
      'Motor hidráulico validado',
      'Hazen-Williams, Darcy-Weisbach, Scobey e Manning, perdas localizadas pelas conexões usadas, emissores q = k·Hˣ, solver de rede pelo Global Gradient Algorithm (como o EPANET), curvas de bomba com NPSH, transientes pelo método das características com ventosas e simulação de 24 horas com tarifas de energia.',
    ),
    (
      'Terreno, clima e agronomia',
      'Curvas de nível, cotas de ponto, modelo do terreno por triangulação com linhas de quebra, elevação baixada da internet, nuvens de pontos LAS, mapas de declividade e perfis; clima do local baixado ou digitado, culturas da FAO-56 por fase, solos, chuva efetiva e lixiviação para a necessidade hídrica, além do orçamento hídrico do paisagismo.',
    ),
    (
      'Relatórios, pranchas e materiais',
      'Zonas, tubos, emissores, uniformidade (CU, DU, EU), programa do controlador e fiação das válvulas; lista de materiais com conexões e orçamento com mão de obra, impostos e retorno do investimento; conjuntos de pranchas em PDF com detalhes construtivos e gráficos, em qualquer um dos 20 idiomas, e todas as tabelas em Excel, CSV e TXT.',
    ),
    (
      'Troca de arquivos',
      'Importa DXF, DWG, plantas em PDF, KML/KMZ, shapefile, GeoJSON, GPX, LandXML, LAS, DGN, EPANET .inp, CSV/XYZ, GeoTIFF e imagens; exporta DXF 2000 com entidades nativas (ou R12), DWG, PDF, PNG, SVG, KML/KMZ, GeoJSON, shapefile, GPX, LandXML, EPANET .inp e IFC.',
    ),
    (
      'Catálogos de fabricantes',
      'Catálogos de fabricantes em JSON (Netafim, Rivulis, Jain, Toro, Rain Bird, Nelson, Hunter, NaanDanJain, Senninger, Irritec, Bermad, Schneider, Amanco Wavin, Multilit) prontos para usar, além de pacotes próprios carregados por arquivo ou URL.',
    ),
    (
      'Sem internet e no campo',
      'Depois da primeira visita o app abre sem internet, no computador, no tablet ou no celular, com tema claro ou escuro. No campo, o GPS do aparelho grava contornos e linhas percorridos a pé, marca pontos e mostra a distância e o rumo até o item selecionado para a marcação.',
    ),
  ],
  howTitle: 'Como funciona',
  how: [
    (
      'Desenhe ou importe a área',
      'Traga um DXF, DWG, KML ou uma imagem de satélite, desenhe o talhão, o jardim ou o campo diretamente, ou diga o endereço ao assistente de IA, que localiza o terreno no mapa. Adicione curvas de nível ou baixe a elevação pela coordenada.',
    ),
    (
      'Monte a rede, à mão ou com a IA',
      'Gere blocos de laterais ou grades de aspersores com um clique, ou peça ao assistente de IA que distribua os aspersores, divida o talhão, trace os tubos e posicione válvulas, bomba e fonte de água; depois ligue tudo pela linha principal.',
    ),
    ('Projete e documente', 'Pressione F5, ou peça à IA: o app dimensiona zonas e linha principal, verifica pressões e velocidades e produz relatórios, lista de materiais e a prancha em PDF.'),
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
    (
      'O que é o OpenCADIrrigation?',
      'O OpenCADIrrigation é um aplicativo web gratuito e de código aberto para projetar sistemas de irrigação pressurizada: um CAD com motor hidráulico que desenha a rede, dimensiona as tubulações, verifica pressões e uniformidade e produz a lista de materiais e os relatórios, do jardim residencial ao pivô central, mais um assistente de IA opcional que desenha e projeta com você a partir de uma descrição do terreno.',
    ),
    (
      'Uma IA pode fazer o projeto por mim?',
      'Sim, se você quiser. O assistente de IA, que é opcional, trabalha no projeto aberto com as mesmas ferramentas dos menus: descreva o terreno, ou deixe que ele olhe a imagem de satélite e o relevo de um projeto georreferenciado, e ele distribui aspersores e gotejamento, divide talhões em blocos, traça tubos e válvulas, posiciona a bomba e a fonte de água, roda o dimensionamento e as ferramentas automáticas, corrige os avisos, otimiza o custo e escreve o memorial. Ele pergunta antes de cada alteração, ou aplica as alterações automaticamente se você escolher, e cada resposta pode ser desfeita com um clique. Um modelo pode errar: confira o trabalho dele como conferiria o de um colega.',
    ),
    (
      'Quais modelos de IA ele usa?',
      'Modelos Claude da Anthropic (Claude Opus 5.5 por padrão, Claude Fable 5.1, Claude Sonnet 5.5 e Claude Haiku 5.5) e modelos GPT da OpenAI (GPT-6 Astra, GPT-6.1 Sol e GPT-6 Luna): um nível topo, um intermediário e um rápido de cada empresa, cada um com cinco profundidades de raciocínio. Você escolhe o modelo nas configurações do assistente e cola a sua própria chave de API; o painel mostra os tokens e o custo estimado de cada resposta, e um limite de passos e um teto de gasto encerram uma tarefa que se alonga.',
    ),
    (
      'O que o assistente de IA envia, e para onde?',
      'Nada até você clicar em Enviar. Então a sua mensagem, os arquivos anexados e os dados do projeto que você marcar vão direto do seu navegador para a API do provedor escolhido, Anthropic ou OpenAI, sem nenhum servidor do OpenCADIrrigation no meio, junto com os resultados das ferramentas que ele usa enquanto responde, inclusive imagens do desenho. O provedor cobra o uso na sua conta. A chave fica só na memória durante a sessão, a menos que você escolha lembrá-la no aparelho, e nunca vai para arquivos de projeto, links de compartilhamento ou exportações. O ditado por voz, se você usar, é feito pelo reconhecimento de fala do próprio navegador, que envia o áudio para a empresa do navegador (Google no Chrome, Microsoft no Edge, Apple no Safari). As conversas guardadas ficam no seu navegador, nunca em arquivos de projeto ou links.',
    ),
    (
      'O OpenCADIrrigation é gratuito?',
      'Sim. É gratuito para uso profissional, acadêmico e pessoal, sem cadastro. Também é de código aberto, sob a licença MIT, com o código-fonte publicado no GitHub. O assistente de IA, que é opcional, usa a sua própria conta da Anthropic ou da OpenAI, e o provedor cobra o uso nessa conta.',
    ),
    (
      'Para quem ele é?',
      'Para projetistas de irrigação agrícola e paisagística, agrônomos e engenheiros, revendas de equipamentos, professores e estudantes. O tutorial interativo, 15 exemplos prontos e o assistente de IA permitem começar sem ler manual.',
    ),
    (
      'Preciso instalar alguma coisa?',
      'Não. Ele roda em Chrome, Edge, Firefox e Safari, no computador, no tablet e no celular, e pode ser instalado como aplicativo (PWA) para abrir em janela própria.',
    ),
    (
      'Funciona sem internet?',
      'Sim, depois da primeira visita: o app guarda uma cópia de si mesmo no navegador (cerca de 20 MB, uma vez por versão), e a próxima abertura, do app instalado ou do site, funciona sem rede, no escritório ou no campo. Mapas base, elevação e clima online, catálogos carregados por URL e o assistente de IA continuam precisando de conexão; uma versão nova é baixada em segundo plano: o app oferece recarregar nela, ou ela é usada a partir da abertura seguinte.',
    ),
    (
      'Meus projetos ficam na nuvem?',
      'Não. Os projetos são salvos no seu navegador e em arquivos .oci.json que você guarda onde quiser; um link de compartilhamento leva o projeto dentro do próprio endereço, sem enviar nada, e o OpenCADIrrigation não tem servidor que pudesse guardar uma cópia. As fontes de todas as escritas e símbolos vêm do próprio site. O navegador acessa outros serviços: mapas base, elevação e clima online, busca de endereços, catálogos carregados por URL e, se você usar, o assistente de IA (só o provedor que você escolheu, Anthropic ou OpenAI) vão aos seus serviços quando você os usa; e o site e o app contam as visitas com o Google Analytics, que usa cookies (Preferências de cookies, no rodapé das páginas, o desliga). A política de privacidade lista cada serviço e o que ele recebe.',
    ),
    (
      'Como é feito o cálculo hidráulico?',
      'Perda de carga por Hazen-Williams, Darcy-Weisbach, Scobey ou Manning, emissores por q = k·Hˣ e a rede inteira resolvida pelo Global Gradient Algorithm, o método do EPANET. As tubulações são dimensionadas por programação linear dentro da janela de pressão dos emissores e da classe de pressão dos tubos, e o projeto verifica também uniformidade (CU, DU, EU), lavagem e transientes pelo método das características (fechamento de válvulas, parada de bomba, ventosas), com simulação de 24 horas das pressões e do custo de energia.',
    ),
    (
      'Funciona com outros programas de CAD?',
      'Sim. Importa DXF e DWG até a versão 2018, DGN V7 e plantas em PDF, e exporta DXF 2000 com entidades nativas (polilinhas com arcos, hachuras, splines, cotas, blocos com atributos), DXF R12 para programas antigos e DWG 2000. Para SIG, topografia e BIM, também lê e grava KML/KMZ, shapefile, GeoJSON, GPX, LandXML e EPANET .inp, lê nuvens de pontos LAS e exporta IFC 4.',
    ),
    (
      'Em que idiomas está disponível?',
      'Em 20 idiomas, os mesmos deste site (a lista está no rodapé da página). O app abre no idioma do seu computador e você pode trocar a qualquer momento em Ver → Idioma.',
    ),
  ],
  loading: 'Carregando o CAD de irrigação…',
  slow: 'O carregamento está demorando. Verifique a conexão ou recarregue a página; o conteúdo acima já pode ser lido.',
  noScript: 'O OpenCADIrrigation precisa de JavaScript para funcionar. Ative o JavaScript no navegador e recarregue a página.',
  otherLanguages: 'Idiomas',
  footer: 'Catálogos de fabricantes e exemplos de projeto podem ser enviados em formato JSON para inclusão no OpenCADIrrigation.',
  sourceCode: 'Código-fonte (licença MIT)',
  subCategory: 'CAD para irrigação',
  screenshotLabel: 'Projeto de irrigação dimensionado com resultados por zona',
  notFoundTitle: 'Página não encontrada',
  notFoundText: 'O endereço não existe neste site. O OpenCADIrrigation é um único aplicativo; abra-o pela página inicial.',
  notFoundHome: 'Ir para o OpenCADIrrigation',
);

const _en = SiteText(
  title: 'OpenCADIrrigation: free irrigation design software with AI',
  description: 'Free, open-source irrigation design software with an AI assistant that lays out sprinklers and drip, routes pipes and sizes the system in your browser.',
  keywords: 'AI irrigation design, AI irrigation design software, irrigation design software, free irrigation design software, open-source irrigation software, irrigation CAD, automatic irrigation design, automatic sprinkler layout, irrigation AI assistant, drip irrigation design, sprinkler design, centre pivot, hydraulic design, pipe sizing, irrigation uniformity, DXF, DWG, landscape irrigation, agricultural irrigation, free irrigation software',
  h1: 'Free, open-source irrigation design software with an AI assistant',
  tagline: 'Describe the field, the garden or the pitch and let the AI assistant lay out the heads and the drip, route the pipes and size the system; or draw it yourself with the automatic tools. Drip, micro-sprinkler, sprinkler and centre-pivot systems, right in the browser, nothing to install, with your projects kept on your own computer.',
  intro: 'OpenCADIrrigation brings CAD drawing, the hydraulic network, the calculation and an AI assistant together. Trace the area, or let the AI find the site on the satellite image; lay out laterals, valves and the mainline by hand, with the one-click generators or by asking the AI; press F5 and get pipe sizes, pressures, uniformity, operating shifts, a bill of materials and printable reports. The assistant runs Claude (Anthropic) or GPT (OpenAI) models with your own API key, straight from the browser. Available in 20 languages, following your computer\'s language.',
  openApp: 'Open the app',
  tutorial: 'Interactive tutorial',
  seeExamples: 'See ready examples',
  aiTitle: 'An AI assistant that draws and designs with you',
  aiIntro: 'Open the AI panel beside the drawing and ask in your own words. The assistant reads the project, looks at the satellite image and the terrain and works with the same tools as the menus, so what it draws is a real design: items, pipes, valves, zones and results, not a picture. Every change waits for your approval, or applies automatically if you prefer, and can be undone in one click.',
  aiPoints: [
    (
      'Draws and designs automatically',
      'Lays out sprinklers and drip lines, divides fields into blocks, fits pivots, routes pipes and valves, places the pump and the water supply, runs the design, fixes the warnings and optimises the cost, then writes the technical report and the quote.',
    ),
    (
      'Sees the site',
      'Finds the site from an address, looks at the satellite image of a georeferenced project and at the terrain (hillshade, contours, slope, profiles), reads the drawings and GIS files you attach and adds catalogue items from a data sheet in PDF. Outlines the fields on the image by itself, follows the points and lines you mark on the map and pins field photos with GPS where they were taken.',
    ),
    (
      'Explains and checks',
      'Answers questions about the project and its results, explains every design message and how to fix it, runs the analyses and keeps a to-do list and notes of your decisions in the project. On request, reviews the whole design without changing anything, and looks at the drawing sheet before you export it.',
    ),
    (
      'Your key, your control',
      'Claude (Anthropic) or GPT (OpenAI) models in top, intermediate and fast tiers, with your own API key, called straight from the browser with no server in between. Read-only, plan-first, ask-before-each-change or automatic modes, a step limit and a spending cap per task, undo for every answer, and nothing sent before you press Send.',
    ),
  ],
  aiCta: 'Open the AI assistant',
  featuresTitle: 'What OpenCADIrrigation does',
  features: [
    (
      'AI assistant',
      'Optional: ask the AI about the project, or let it draw and design for you. It lays out heads and drip, divides fields, routes pipes, runs the sizing and the automatic tools, looking at the satellite image and the terrain, with Claude (Anthropic) or GPT (OpenAI) models and your own API key, straight from the browser with no server in between. Nothing is sent before you press Send, and every change waits for your approval (or applies automatically, if you choose) and can be undone.',
    ),
    (
      'Automatic design and sizing',
      'Lateral blocks and sprinkler grids in one click, head layout with matched precipitation, zoning by flow, pipe and valve routing, field subdivision, pivot fit and vegetation detection in aerial images; pipes sized by linear programming within the emitter pressure window and the pipe pressure class, trading pipe cost against energy.',
    ),
    (
      'Full CAD drawing',
      'Lines, polylines, arcs, splines, hatches, dimensions, text, layers and blocks, with typed coordinates, snaps, polar tracking, grips, revision clouds and the command shortcuts of CAD programs (L, PL, C, D, ZE…).',
    ),
    (
      'Hydraulic network',
      'Water supplies, fixed and variable-speed pumps, mainline, zone, pressure-reducing, pressure-sustaining and flow-control valves, valve-in-head sprinklers, laterals with emitters, drip tapes, filters and meters, plus centre pivots and linear moves with their sprinkler package, hose-reel travellers and surface irrigation.',
    ),
    (
      'Validated hydraulic engine',
      'Hazen-Williams, Darcy-Weisbach, Scobey and Manning, minor losses from the fittings used, emitters q = k·Hˣ, network solver by the Global Gradient Algorithm (as in EPANET), pump curves with NPSH, transients by the method of characteristics with air valves, and a 24-hour simulation with energy tariffs.',
    ),
    (
      'Terrain, climate and agronomy',
      'Contours, spot heights, a triangulated terrain model with breaklines, online elevation, LAS point clouds, slope maps and profiles; site climate downloaded or typed in, FAO-56 crops by stage, soils, effective rain and leaching for the water requirement, plus landscape water budgets.',
    ),
    (
      'Reports, plans and materials',
      'Zones, pipes, emitters, uniformity (CU, DU, EU), controller programme and valve wiring; a bill of materials with fittings and a quote with labour, taxes and payback; PDF sheet sets with construction details and charts, in any of the 20 languages, and every table in Excel, CSV and TXT.',
    ),
    (
      'File exchange',
      'Imports DXF, DWG, PDF plans, KML/KMZ, shapefiles, GeoJSON, GPX, LandXML, LAS, DGN, EPANET .inp, CSV/XYZ, GeoTIFF and images; exports DXF 2000 with native entities (or R12), DWG, PDF, PNG, SVG, KML/KMZ, GeoJSON, shapefiles, GPX, LandXML, EPANET .inp and IFC.',
    ),
    (
      'Manufacturer catalogues',
      'Manufacturer catalogues in JSON (Netafim, Rivulis, Jain, Toro, Rain Bird, Nelson, Hunter, NaanDanJain, Senninger, Irritec, Bermad, Schneider, Amanco Wavin, Multilit) ready to use, plus your own packs loaded from a file or a URL.',
    ),
    (
      'Offline and in the field',
      'After the first visit the app starts without a network, on desktop, tablet or phone, in a light or dark theme. In the field the device GPS records walked outlines and lines, marks points and gives the distance and bearing to the selected item for staking out.',
    ),
  ],
  howTitle: 'How it works',
  how: [
    (
      'Draw or import the area',
      'Bring a DXF, DWG, KML or a satellite image, draw the field, garden or pitch directly, or tell the AI assistant the address and it finds the site on the map. Add contours or download the elevation from a coordinate.',
    ),
    (
      'Build the network, by hand or with the AI',
      'Generate lateral blocks or sprinkler grids in one click, or ask the AI assistant to lay out the heads, divide the field, route the pipes and place valves, pump and water supply; then connect everything with the mainline.',
    ),
    ('Design and document', 'Press F5, or ask the AI: the app sizes zones and mainline, checks pressures and velocities and produces reports, the bill of materials and the PDF sheet.'),
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
    (
      'What is OpenCADIrrigation?',
      'OpenCADIrrigation is a free, open-source web application for designing pressurised irrigation systems: a CAD with a hydraulic engine that lays out the network, sizes the pipes, checks pressures and uniformity and produces the bill of materials and reports, from a home garden to a centre pivot, plus an optional AI assistant that draws and designs the project with you from a description of the site.',
    ),
    (
      'Can an AI design the project for me?',
      'Yes, if you want it to. The optional AI assistant works on the open project with the same tools as the menus: describe the site, or let it look at the satellite image and the terrain of a georeferenced project, and it lays out sprinklers and drip, divides fields into blocks, routes pipes and valves, places the pump and the water supply, runs the design and the automatic tools, fixes the warnings, optimises the cost and writes the report. It asks before each change, or applies the changes automatically if you choose, and every answer can be undone in one click. A model can be wrong, so check its work as you would a colleague\'s.',
    ),
    (
      'Which AI models does it use?',
      'Claude models from Anthropic (Claude Opus 5.5 by default, Claude Fable 5.1, Claude Sonnet 5.5 and Claude Haiku 5.5) and GPT models from OpenAI (GPT-6 Astra, GPT-6.1 Sol and GPT-6 Luna): a top, an intermediate and a fast tier of each company, each with five depths of reasoning. You choose the model in the assistant\'s settings and paste your own API key; the panel shows the tokens and the estimated cost of every answer, and a step limit and a spending cap end a task that runs long.',
    ),
    (
      'What does the AI assistant send, and where?',
      'Nothing until you press Send. Then your message, the files you attach and the project data you tick go straight from your browser to the API of the provider you chose, Anthropic or OpenAI, with no server of OpenCADIrrigation in between, together with the results of the tools it uses while answering, pictures of the drawing included. The provider bills the use to your account. The key stays in memory for the session unless you choose to remember it on the device, and it never goes into project files, share links or exports. Voice dictation, if you use it, is done by the browser\'s own speech recognition, which sends the audio to the browser maker (Google in Chrome, Microsoft in Edge, Apple in Safari). Saved conversations stay in your browser, never in project files or links.',
    ),
    (
      'Is OpenCADIrrigation free?',
      'Yes. It is free for professional, academic and personal use, with no sign-up. It is also open source under the MIT licence, with the source code published on GitHub. The optional AI assistant uses your own Anthropic or OpenAI account, and the provider bills its use to that account.',
    ),
    (
      'Who is it for?',
      'Agricultural and landscape irrigation designers, agronomists and engineers, equipment dealers, teachers and students. The interactive tutorial, 15 ready examples and the AI assistant let you start without reading a manual.',
    ),
    ('Do I need to install anything?', 'No. It runs in Chrome, Edge, Firefox and Safari on desktop, tablet and phone, and can be installed as an app (PWA) to open in its own window.'),
    (
      'Does it work offline?',
      'Yes, after the first visit: the app keeps a copy of itself in the browser (about 20 MB, once per version), so the next start, of the installed app or of the site, works without a network, in the office or in the field. Base maps, online elevation and climate, catalogues loaded by URL and the AI assistant still need a connection; a new version downloads in the background: the app offers to reload into it, or it is used from the next start.',
    ),
    ('Are my projects stored in the cloud?', faqCloudAnswerEn),
    (
      'How does it calculate the hydraulics?',
      'Friction losses by Hazen-Williams, Darcy-Weisbach, Scobey or Manning, emitters by q = k·Hˣ and the whole network solved by the Global Gradient Algorithm, the method used by EPANET. Pipes are sized by linear programming within the emitter pressure window and the pipe pressure class, and the design also checks uniformity (CU, DU, EU), flushing and transients by the method of characteristics (valve closure, pump trip, air valves), with a 24-hour simulation of pressures and energy cost.',
    ),
    (
      'Does it work with other CAD programs?',
      'Yes. It imports DXF and DWG up to version 2018, DGN V7 and PDF plans, and exports DXF 2000 with native entities (polylines with arcs, hatches, splines, dimensions, blocks with attributes), DXF R12 for older programs and DWG 2000. For GIS, survey and BIM it also reads and writes KML/KMZ, shapefiles, GeoJSON, GPX, LandXML and EPANET .inp, reads LAS point clouds and exports IFC 4.',
    ),
    (
      'Which languages are available?',
      'Twenty, the same as this site (the list is at the foot of the page). The app opens in your computer\'s language and you can switch at any time under View → Language.',
    ),
  ],
  loading: 'Loading the irrigation CAD…',
  slow: 'Loading is taking long. Check the connection or reload the page; the content above can already be read.',
  noScript: 'OpenCADIrrigation needs JavaScript to run. Enable JavaScript in your browser and reload the page.',
  otherLanguages: 'Languages',
  footer: 'Manufacturer catalogues and example projects can be sent as JSON for inclusion in OpenCADIrrigation.',
  sourceCode: 'Source code (MIT licence)',
  subCategory: 'Irrigation CAD',
  screenshotLabel: 'Sized irrigation design with results per zone',
  notFoundTitle: 'Page not found',
  notFoundText: 'That address does not exist on this site. OpenCADIrrigation is a single application; open it from the home page.',
  notFoundHome: 'Go to OpenCADIrrigation',
);

const _es = SiteText(
  title: 'OpenCADIrrigation: software gratuito de diseño de riego con IA',
  description: 'Software gratuito y de código abierto para diseño de riego con asistente de IA que distribuye aspersores y goteo, traza tuberías y dimensiona el sistema.',
  keywords: 'diseño de riego con IA, inteligencia artificial diseño de riego, software de diseño de riego, diseño de riego, software de riego gratis, software de riego de código abierto, diseño automático de riego, distribución automática de aspersores, software de riego, CAD riego, riego presurizado, riego por goteo, microaspersión, aspersión, pivote central, dimensionamiento hidráulico, cálculo de tuberías, uniformidad de riego, DXF, DWG, riego de jardines, riego agrícola',
  h1: 'Software gratuito y de código abierto para diseño de riego con asistente de IA',
  tagline: 'Describa la parcela, el jardín o el campo y deje que el asistente de IA distribuya los aspersores y el goteo, trace las tuberías y dimensione el sistema; o dibújelo usted mismo con las herramientas automáticas. Goteo, microaspersión, aspersión y pivote central, directamente en el navegador, sin instalar nada, con los proyectos guardados en su propio equipo.',
  intro: 'OpenCADIrrigation reúne en un solo lugar el dibujo CAD, la red hidráulica, el cálculo y un asistente de IA. Trace el área, o deje que la IA localice el terreno en la imagen satelital; coloque laterales, válvulas y línea principal a mano, con los generadores de un clic o pidiéndoselo a la IA; pulse F5 y obtenga diámetros, presiones, uniformidad, turnos de operación, lista de materiales e informes listos para imprimir. El asistente usa modelos Claude (Anthropic) o GPT (OpenAI) con su propia clave de API, directamente desde el navegador. Disponible en 20 idiomas, según el idioma de su equipo.',
  openApp: 'Abrir la aplicación',
  tutorial: 'Tutorial interactivo',
  seeExamples: 'Ver ejemplos listos',
  aiTitle: 'Un asistente de IA que dibuja y diseña con usted',
  aiIntro: 'Abra el panel de IA junto al dibujo y pida lo que necesita con sus propias palabras. El asistente lee el proyecto, mira la imagen satelital y el terreno y trabaja con las mismas herramientas que los menús, de modo que lo que dibuja es un diseño real: elementos, tuberías, válvulas, zonas y resultados, no una imagen. Cada cambio espera su aprobación, o se aplica automáticamente si lo prefiere, y se puede deshacer con un clic.',
  aiPoints: [
    (
      'Dibuja y diseña automáticamente',
      'Distribuye aspersores y líneas de goteo, divide parcelas en bloques, ajusta pivotes, traza tuberías y válvulas, coloca la bomba y la fuente de agua, ejecuta el dimensionamiento, corrige los avisos y optimiza el coste, y después redacta la memoria técnica y el presupuesto.',
    ),
    (
      'Ve el terreno',
      'Localiza el terreno a partir de una dirección, mira la imagen satelital de un proyecto georreferenciado y el relieve (sombreado, curvas de nivel, pendiente, perfiles), lee los dibujos y archivos SIG que usted adjunte y añade elementos al catálogo a partir de una ficha técnica en PDF. Contornea por sí solo las parcelas en la imagen, sigue los puntos y las líneas que usted marque en el mapa y fija en el dibujo las fotos de campo con GPS, en el lugar donde se tomaron.',
    ),
    (
      'Explica y verifica',
      'Responde preguntas sobre el proyecto y sus resultados, explica cada mensaje del dimensionamiento y cómo corregirlo, ejecuta los análisis y mantiene en el proyecto una lista de tareas y notas con sus decisiones. Cuando se lo pide, revisa todo el diseño sin cambiar nada y mira la lámina antes de que usted la exporte.',
    ),
    (
      'Su clave, su control',
      'Modelos Claude (Anthropic) o GPT (OpenAI) en niveles superior, intermedio y rápido, con su propia clave de API, llamados directamente desde el navegador, sin servidor intermedio. Modos de solo lectura, planificar primero, preguntar antes de cada cambio o automático, límite de pasos y de gasto por tarea, deshacer para cada respuesta y nada enviado antes de pulsar Enviar.',
    ),
  ],
  aiCta: 'Abrir el asistente de IA',
  featuresTitle: 'Qué hace OpenCADIrrigation',
  features: [
    (
      'Asistente de IA',
      'Opcional: pregunte a la IA sobre el proyecto o deje que dibuje y diseñe por usted. Distribuye aspersores y goteo, divide parcelas, traza tuberías, ejecuta el dimensionamiento y las herramientas automáticas, mirando la imagen satelital y el terreno, con modelos Claude (Anthropic) o GPT (OpenAI) y su propia clave de API, directamente desde el navegador y sin servidor intermedio. No se envía nada antes de pulsar Enviar, y cada cambio espera su aprobación (o se aplica automáticamente, si así lo elige) y se puede deshacer.',
    ),
    (
      'Diseño y dimensionamiento automáticos',
      'Bloques de laterales y mallas de aspersores con un clic, distribución de aspersores con precipitación equilibrada, zonificación por caudal, trazado de tuberías y válvulas, división de parcelas en bloques, ajuste de pivotes y detección de vegetación en imágenes aéreas; tuberías dimensionadas por programación lineal dentro de la ventana de presión de los emisores y la clase de presión de las tuberías, equilibrando coste de tubería y energía.',
    ),
    (
      'Dibujo CAD completo',
      'Líneas, polilíneas, arcos, splines, sombreados, cotas, textos, capas y bloques, con entrada de coordenadas, referencias a objetos, rastreo polar, pinzamientos, nubes de revisión y los atajos de comandos de los programas de CAD (L, PL, C, D, ZE…).',
    ),
    (
      'Red hidráulica',
      'Fuentes de agua, bombas de velocidad fija o variable, línea principal, válvulas de zona, reductoras y sostenedoras de presión y limitadoras de caudal, aspersores con válvula incorporada, laterales con emisores, cintas de goteo, filtros y contadores, además de pivotes centrales y lineales con su paquete de aspersores, cañones viajeros y riego por superficie.',
    ),
    (
      'Motor hidráulico validado',
      'Hazen-Williams, Darcy-Weisbach, Scobey y Manning, pérdidas localizadas de los accesorios usados, emisores q = k·Hˣ, resolución de redes por el Global Gradient Algorithm (como EPANET), curvas de bomba con NPSH, transitorios por el método de las características con ventosas y simulación de 24 horas con tarifas de energía.',
    ),
    (
      'Terreno, clima y agronomía',
      'Curvas de nivel, cotas, modelo del terreno por triangulación con líneas de quiebre, elevación descargada de internet, nubes de puntos LAS, mapas de pendientes y perfiles; clima del sitio descargado o introducido a mano, cultivos de la FAO-56 por etapa, suelos, lluvia efectiva y lavado de sales para las necesidades de agua, además del presupuesto hídrico del paisajismo.',
    ),
    (
      'Informes, planos y materiales',
      'Zonas, tuberías, emisores, uniformidad (CU, DU, EU), programa del controlador y cableado de válvulas; lista de materiales con accesorios y presupuesto con mano de obra, impuestos y retorno de la inversión; juegos de planos en PDF con detalles constructivos y gráficos, en cualquiera de los 20 idiomas, y todas las tablas en Excel, CSV y TXT.',
    ),
    (
      'Intercambio de archivos',
      'Importa DXF, DWG, planos en PDF, KML/KMZ, shapefile, GeoJSON, GPX, LandXML, LAS, DGN, EPANET .inp, CSV/XYZ, GeoTIFF e imágenes; exporta DXF 2000 con entidades nativas (o R12), DWG, PDF, PNG, SVG, KML/KMZ, GeoJSON, shapefile, GPX, LandXML, EPANET .inp e IFC.',
    ),
    (
      'Catálogos de fabricantes',
      'Catálogos de fabricantes en JSON (Netafim, Rivulis, Jain, Toro, Rain Bird, Nelson, Hunter, NaanDanJain, Senninger, Irritec, Bermad, Schneider, Amanco Wavin, Multilit) listos para usar, además de paquetes propios cargados desde archivo o URL.',
    ),
    (
      'Sin conexión y en campo',
      'Tras la primera visita la aplicación se abre sin conexión, en ordenador, tableta o móvil, con tema claro u oscuro. En campo, el GPS del dispositivo graba contornos y líneas recorridos a pie, marca puntos e indica la distancia y el rumbo hasta el elemento seleccionado para el replanteo.',
    ),
  ],
  howTitle: 'Cómo funciona',
  how: [
    (
      'Dibuje o importe el área',
      'Traiga un DXF, DWG, KML o una imagen satelital, dibuje la parcela, el jardín o el campo directamente, o dígale la dirección al asistente de IA, que localiza el terreno en el mapa. Añada curvas de nivel o descargue la elevación por coordenada.',
    ),
    (
      'Arme la red, a mano o con la IA',
      'Genere bloques de laterales o mallas de aspersores con un clic, o pida al asistente de IA que distribuya los aspersores, divida la parcela, trace las tuberías y coloque válvulas, bomba y fuente de agua; después conéctelo todo con la línea principal.',
    ),
    (
      'Diseñe y documente',
      'Pulse F5, o pídaselo a la IA: la aplicación dimensiona zonas y línea principal, verifica presiones y velocidades y produce informes, lista de materiales y el plano en PDF.',
    ),
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
    (
      '¿Qué es OpenCADIrrigation?',
      'OpenCADIrrigation es una aplicación web gratuita y de código abierto para diseñar sistemas de riego presurizado: un CAD con motor hidráulico que traza la red, dimensiona las tuberías, verifica presiones y uniformidad y produce la lista de materiales y los informes, desde un jardín residencial hasta un pivote central, más un asistente de IA opcional que dibuja y diseña el proyecto con usted a partir de una descripción del terreno.',
    ),
    (
      '¿Puede una IA hacer el proyecto por mí?',
      'Sí, si usted quiere. El asistente de IA, que es opcional, trabaja en el proyecto abierto con las mismas herramientas que los menús: describa el terreno, o deje que mire la imagen satelital y el relieve de un proyecto georreferenciado, y distribuye aspersores y goteo, divide parcelas en bloques, traza tuberías y válvulas, coloca la bomba y la fuente de agua, ejecuta el dimensionamiento y las herramientas automáticas, corrige los avisos, optimiza el coste y redacta la memoria. Pregunta antes de cada cambio, o aplica los cambios automáticamente si usted lo elige, y cada respuesta se puede deshacer con un clic. Un modelo puede equivocarse: revise su trabajo como revisaría el de un colega.',
    ),
    (
      '¿Qué modelos de IA utiliza?',
      'Modelos Claude de Anthropic (Claude Opus 5.5 por defecto, Claude Fable 5.1, Claude Sonnet 5.5 y Claude Haiku 5.5) y modelos GPT de OpenAI (GPT-6 Astra, GPT-6.1 Sol y GPT-6 Luna): un nivel superior, uno intermedio y uno rápido de cada empresa, cada uno con cinco profundidades de razonamiento. Usted elige el modelo en los ajustes del asistente y pega su propia clave de API; el panel muestra los tokens y el coste estimado de cada respuesta, y un límite de pasos y un tope de gasto terminan una tarea que se alarga.',
    ),
    (
      '¿Qué envía el asistente de IA, y adónde?',
      'Nada hasta que pulse Enviar. Entonces su mensaje, los archivos adjuntos y los datos del proyecto que marque van directamente desde su navegador a la API del proveedor elegido, Anthropic u OpenAI, sin ningún servidor de OpenCADIrrigation de por medio, junto con los resultados de las herramientas que usa mientras responde, imágenes del dibujo incluidas. El proveedor factura el uso en su cuenta. La clave queda solo en la memoria durante la sesión, a menos que elija recordarla en el dispositivo, y nunca va a archivos de proyecto, enlaces de compartir ni exportaciones. El dictado por voz, si lo usa, lo hace el reconocimiento de voz del propio navegador, que envía el audio a la empresa del navegador (Google en Chrome, Microsoft en Edge, Apple en Safari). Las conversaciones guardadas quedan en su navegador, nunca en archivos de proyecto ni enlaces.',
    ),
    (
      '¿OpenCADIrrigation es gratuito?',
      'Sí. Es gratuito para uso profesional, académico y personal, sin registro. Además es de código abierto, con licencia MIT, y el código fuente está publicado en GitHub. El asistente de IA, que es opcional, usa su propia cuenta de Anthropic o de OpenAI, y el proveedor factura el uso en esa cuenta.',
    ),
    (
      '¿Para quién es?',
      'Para proyectistas de riego agrícola y paisajístico, agrónomos e ingenieros, distribuidores de equipos, profesores y estudiantes. El tutorial interactivo, 15 ejemplos listos y el asistente de IA permiten empezar sin leer un manual.',
    ),
    ('¿Necesito instalar algo?', 'No. Funciona en Chrome, Edge, Firefox y Safari, en ordenador, tableta y móvil, y puede instalarse como aplicación (PWA) para abrirse en su propia ventana.'),
    (
      '¿Funciona sin conexión?',
      'Sí, después de la primera visita: la aplicación guarda una copia de sí misma en el navegador (unos 20 MB, una vez por versión), y el siguiente inicio, de la aplicación instalada o del sitio, funciona sin red, en la oficina o en el campo. Los mapas base, la elevación y el clima en línea, los catálogos cargados por URL y el asistente de IA siguen necesitando conexión; una versión nueva se descarga en segundo plano: la aplicación ofrece recargarla, o se usa a partir del siguiente inicio.',
    ),
    (
      '¿Mis proyectos se guardan en la nube?',
      'No. Los proyectos se guardan en su navegador y en archivos .oci.json que usted conserva donde quiera; un enlace para compartir lleva el proyecto dentro de la propia dirección, sin subir nada, y OpenCADIrrigation no tiene ningún servidor que pudiera guardar una copia. Las fuentes de todas las escrituras y símbolos vienen del propio sitio. El navegador sí accede a otros servicios: los mapas base, la elevación y el clima en línea, la búsqueda de direcciones, los catálogos cargados por URL y, si lo usa, el asistente de IA (solo el proveedor que usted eligió, Anthropic u OpenAI) van a sus servicios cuando los usa; y el sitio y la aplicación cuentan las visitas con Google Analytics, que usa cookies (Preferencias de cookies, al pie de las páginas, lo desactiva). La política de privacidad enumera cada servicio y lo que recibe.',
    ),
    (
      '¿Cómo se hace el cálculo hidráulico?',
      'Pérdidas de carga por Hazen-Williams, Darcy-Weisbach, Scobey o Manning, emisores por q = k·Hˣ y toda la red resuelta por el Global Gradient Algorithm, el método de EPANET. Las tuberías se dimensionan por programación lineal dentro de la ventana de presión de los emisores y la clase de presión de las tuberías, y el diseño verifica también la uniformidad (CU, DU, EU), el lavado y los transitorios por el método de las características (cierre de válvulas, parada de bombas, ventosas), con una simulación de 24 horas de las presiones y el coste de la energía.',
    ),
    (
      '¿Funciona con otros programas de CAD?',
      'Sí. Importa DXF y DWG hasta la versión 2018, DGN V7 y planos en PDF, y exporta DXF 2000 con entidades nativas (polilíneas con arcos, sombreados, splines, cotas, bloques con atributos), DXF R12 para programas antiguos y DWG 2000. Para SIG, topografía y BIM también lee y escribe KML/KMZ, shapefile, GeoJSON, GPX, LandXML y EPANET .inp, lee nubes de puntos LAS y exporta IFC 4.',
    ),
    (
      '¿En qué idiomas está disponible?',
      'En 20 idiomas, los mismos de este sitio (la lista está al pie de la página). La aplicación se abre en el idioma de su equipo y puede cambiarlo en cualquier momento en Ver → Idioma.',
    ),
  ],
  loading: 'Cargando el CAD de riego…',
  slow: 'La carga está tardando. Compruebe la conexión o recargue la página; el contenido de arriba ya puede leerse.',
  noScript: 'OpenCADIrrigation necesita JavaScript para funcionar. Active JavaScript en el navegador y recargue la página.',
  otherLanguages: 'Idiomas',
  footer: 'Los catálogos de fabricantes y los proyectos de ejemplo pueden enviarse en formato JSON para incluirse en OpenCADIrrigation.',
  sourceCode: 'Código fuente (licencia MIT)',
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

/// Widths of the logo at the top of the entry pages
/// (`web/brand/logo-horizontal-<width>.webp`, encoded from
/// `logo-horizontal.png`): it is shown 520 px wide, 78 % of the width on a
/// phone, at 1× to 2× pixel density.
const landingLogoWidths = [520, 780, 1040];

/// Address of the landing logo [width] wide.
String landingLogo(int width) => versioned('brand/logo-horizontal-$width.webp');

/// Widths of the app screenshot under "How it works"
/// (`web/screenshots/design-<width>.webp`, encoded from
/// `design-1440x900.png`): up to 940 px wide on the page, at 1× to 1.5×.
const landingShotWidths = [720, 1080, 1440];

/// The sharing image (Open Graph, Twitter card) of [lang]: the English
/// `og-image.png` at the root, and for every other language its logo and
/// heading in its own script (`web/og/og-image-<code>.jpg`, rendered from
/// the page by `node tool/og/render_og.js`), versioned by its content.
String ogImage(SiteLang lang) => lang.isRoot ? 'og-image.png' : versioned('og/og-image-${lang.code}.jpg');

/// Address of the landing screenshot [width] wide.
String landingShot(int width) => versioned('screenshots/design-$width.webp');

/// Address of the file at [path] inside `web/`, versioned by its content:
/// firebase.json lets browsers keep images for a month, and a new image gets
/// a new address.
String versioned(String path) => '$path?v=${_fnv(File('web/$path').readAsBytesSync())}';

/// 32-bit FNV-1a of [bytes], in hex: the version of a file in its address.
String _fnv(List<int> bytes) {
  var hash = 0x811c9dc5;
  for (final byte in bytes) {
    hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

/// hreflang values of [l]: its BCP 47 tag and, when the tag names a region
/// (pt-BR, zh-CN), the bare language as well, so that the speakers of the
/// language elsewhere (Portugal, Angola, Singapore…) are sent to the page
/// in their language and not to the English default.
List<String> hreflangsOf(SiteLang l) => [l.tag, if (l.tag != l.code) l.code];

String _hreflangLinks() => [
  for (final l in siteLanguages)
    for (final h in hreflangsOf(l)) '  <link rel="alternate" hreflang="$h" href="${l.url}">',
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
  ('Artificial intelligence', 'Artificial_intelligence', 'Q11660'),
  ('Large language model', 'Large_language_model', 'Q115305900'),
];

/// Licence of the application and its source code.
const licenseUrl = 'https://opensource.org/license/mit';

/// JSON-LD graph of a page: organisation, web site, this web page, a
/// one-level breadcrumb, the application, its source code, its FAQ, how it
/// works and the example gallery, all in the language of the page.
String jsonLd(SiteLang lang) {
  final t = siteText(lang.code);
  final graph = [
    {
      '@type': 'Organization',
      '@id': '$siteUrl#org',
      'name': 'OpenCADIrrigation',
      'url': siteUrl,
      'logo': {'@type': 'ImageObject', 'url': '${siteUrl}brand/logo-square.png', 'width': 1254, 'height': 1254},
      'sameAs': [appRepositoryUrl],
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
      'primaryImageOfPage': {'@type': 'ImageObject', 'url': '$siteUrl${ogImage(lang)}', 'width': 1200, 'height': 630},
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
      'image': '$siteUrl${ogImage(lang)}',
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
      'license': licenseUrl,
      'offers': {'@type': 'Offer', 'price': '0', 'priceCurrency': 'USD', 'availability': 'https://schema.org/InStock'},
      'inLanguage': [for (final l in siteLanguages) l.tag],
      'keywords': t.keywords,
      'featureList': [for (final (name, text) in t.features) '$name: $text'],
      'about': [
        for (final (name, article, wikidata) in _subjects)
          {
            '@type': 'Thing',
            'name': name,
            'sameAs': ['https://en.wikipedia.org/wiki/$article', 'https://www.wikidata.org/wiki/$wikidata'],
          },
      ],
      'author': {'@id': '$siteUrl#org'},
      'publisher': {'@id': '$siteUrl#org'},
    },
    {
      '@type': 'SoftwareSourceCode',
      '@id': '$siteUrl#code',
      'name': 'OpenCADIrrigation',
      'description': t.description,
      'url': appRepositoryUrl,
      'codeRepository': appRepositoryUrl,
      'license': licenseUrl,
      'programmingLanguage': 'Dart',
      'runtimePlatform': 'Flutter (web)',
      'version': appVersion,
      'targetProduct': {'@id': '$siteUrl#app'},
      'author': {'@id': '$siteUrl#org'},
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
    #oci-landing .bar { visibility: hidden; width: min(280px, 60vw); height: 3px; margin: 18px auto 6px; background: #263238; border-radius: 2px; overflow: hidden; }
    #oci-landing .bar span { display: block; width: 40%; height: 100%; background: linear-gradient(90deg, #0D47A1, #29B6F6); border-radius: 2px; }
    #oci-landing.oci-starting .bar { visibility: visible; }
    #oci-landing.oci-starting .bar span { animation: oci-slide 1.2s ease-in-out infinite; }
    @keyframes oci-slide { 0% { transform: translateX(-100%); } 100% { transform: translateX(260%); } }
    #oci-landing .status { text-align: center; color: #90A4AE; font-size: .95rem; min-height: 1.55em; margin: 0; }
    #oci-landing .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 14px; margin: 0; padding: 0; list-style: none; }
    #oci-landing .grid li { background: #1B1F24; border: 1px solid #263238; border-radius: 10px; padding: 14px 16px; }
    #oci-landing .grid.pair { grid-template-columns: repeat(2, minmax(0, 1fr)); }
    @media (max-width: 640px) { #oci-landing .grid.pair { grid-template-columns: 1fr; } }
    #oci-landing ol.steps { padding-inline-start: 1.3em; }
    #oci-landing ol.steps li { margin: 8px 0; }
    #oci-landing figure { margin: 22px 0 0; }
    #oci-landing figure img { display: block; width: 100%; height: auto; border: 1px solid #263238; border-radius: 10px; box-shadow: 0 10px 30px rgba(0,0,0,.4); }
    #oci-landing figcaption { margin-top: 8px; text-align: center; color: #90A4AE; font-size: .92rem; }
    #oci-landing dl dt { font-weight: 600; color: #ECEFF1; margin-top: 14px; }
    #oci-landing dl dd { margin: 4px 0 0; }
    #oci-landing footer { margin-top: 44px; padding-top: 16px; border-top: 1px solid #263238; color: #90A4AE; font-size: .92rem; }
    #oci-landing footer nav { line-height: 1.9; }
    #oci-landing footer .meta { font-size: .85rem; color: #78909C; }
    #oci-landing footer time { white-space: nowrap; }
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
  <meta http-equiv="Content-Security-Policy" content="$contentSecurityPolicy">
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
  <meta property="og:image" content="$siteUrl${ogImage(lang)}">
  <meta property="og:image:secure_url" content="$siteUrl${ogImage(lang)}">
  <meta property="og:image:type" content="${lang.isRoot ? 'image/png' : 'image/jpeg'}">
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
  <meta name="twitter:image" content="$siteUrl${ogImage(lang)}">
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
  <link rel="manifest" href="${lang.path}manifest.json">

  <script type="application/ld+json">
${jsonLd(lang)}
  </script>

  <style>$_style$_consentStyle  </style>
</head>
<body>
  <noscript><div id="oci-noscript"${lang.dirAttr}>${_esc(t.noScript)}</div></noscript>
  <!-- Readable content: the page itself until the app is opened, hidden (kept in the page) on Flutter's first frame. -->
  <main id="oci-landing"${lang.dirAttr} data-loading="${_esc(t.loading)}" data-slow="${_esc(t.slow)}">
    <div class="wrap">
      <header>
        <img src="${landingLogo(landingLogoWidths.first)}" srcset="${[for (final w in landingLogoWidths) '${landingLogo(w)} ${w}w'].join(', ')}" sizes="(max-width: 666px) 78vw, 520px" alt="OpenCADIrrigation" width="1040" height="349" fetchpriority="high">
        <h1>${_esc(t.h1)}</h1>
        <p class="tagline">${_esc(t.tagline)}</p>
        <nav class="cta" aria-label="${_esc(t.openApp)}">
          <a class="primary" href="${lang.url}" data-app>${_esc(t.openApp)}</a>
          <a href="${lang.url}?ai=1" data-app>${_esc(t.aiCta)}</a>
          <a href="${lang.url}?tutorial=1" data-app>${_esc(t.tutorial)}</a>
          <a href="#exemplos">${_esc(t.seeExamples)}</a>
        </nav>
        <div class="bar" aria-hidden="true"><span></span></div>
        <p class="status" id="oci-status" role="status" aria-live="polite"></p>
      </header>
      <p>${_esc(t.intro)}</p>

      <section aria-labelledby="oci-ai">
        <h2 id="oci-ai">${_esc(t.aiTitle)}</h2>
        <p>${_esc(t.aiIntro)}</p>
        <ul class="grid pair">''');
  for (final (name, text) in t.aiPoints) {
    b.writeln('          <li><h3>${_esc(name)}</h3><p>${_esc(text)}</p></li>');
  }
  b.writeln('''        </ul>
        <p class="cta"><a class="primary" href="${lang.url}?ai=1" data-app>${_esc(t.aiCta)}</a></p>
      </section>

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
        <figure>
          <img src="${landingShot(landingShotWidths.first)}" srcset="${[for (final w in landingShotWidths) '${landingShot(w)} ${w}w'].join(', ')}" sizes="(max-width: 980px) calc(100vw - 40px), 940px" alt="${_esc(t.screenshotLabel)}" width="1440" height="900" loading="lazy" decoding="async">
          <figcaption>${_esc(t.screenshotLabel)}</figcaption>
        </figure>
      </section>

      <section id="exemplos" aria-labelledby="oci-examples">
        <h2 id="oci-examples">${_esc(t.examplesTitle)}</h2>
        <p>${_esc(t.examplesIntro)}</p>
        <ul class="grid">''');
  for (final ex in t.examples) {
    b.writeln('          <li><h3><a href="${lang.url}?example=${ex.id}" data-app>${_esc(ex.title)}</a></h3><p>${_esc(ex.text)}</p></li>');
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
        <p class="meta">OpenCADIrrigation $appVersion · <a href="$appRepositoryUrl">${_esc(t.sourceCode)}</a> · ${manualLink(lang)} · ${legalLinks(lang)} · <time datetime="$siteLastMod">$siteLastMod</time></p>
      </footer>
    </div>
${consentNotice(lang, legalText(lang.code))}
  </main>
  ${siteScriptTag(absolute: false)}
</body>
</html>''');
  return b.toString();
}

/// Name of the user guide in the footer of the entry pages (the guide is
/// written in English and Portuguese; the other languages link to the
/// English one, under its English name until the next translation pass).
const _manualLabels = {'pt': 'Guia do usuário', 'en': 'User guide', 'es': 'Guía del usuario'};

/// The footer link of [lang] to the user guide (tool/site_manual.dart):
/// the Portuguese guide from the Portuguese page, the English one elsewhere.
String manualLink(SiteLang lang) {
  final label = _manualLabels[lang.code];
  final guideLang = manualSources.containsKey(lang.code) ? lang : siteLang('en');
  final marked = label == null || !manualSources.containsKey(lang.code) ? ' hreflang="${guideLang.tag}"' : '';
  final own = label == null ? ' lang="en"' : '';
  return '<a href="${manualUrl(lang.code)}"$marked$own>${_esc(label ?? _manualLabels['en']!)}</a>';
}

/// Address of the site script, versioned by its content (the page asks for
/// a new address when the script changes).
String siteScriptPath() => 'site.js?v=${_fnv(utf8.encode(renderSiteScript()))}';

/// The script element of a page: `site.js` with the measurement id of the
/// statistics. Relative on the entry pages (their base is the site root, or
/// the folder the root page is served from), absolute on the legal pages.
String siteScriptTag({bool absolute = true}) => '<script src="${absolute ? '/' : ''}${siteScriptPath()}" data-ga="$analyticsId" defer></script>';

/// `site.js`, the only script of the site's own pages (no inline script, so
/// that the Content Security Policy allows the site's files alone):
///
/// - on an entry page it starts the app when it is wanted (an app address,
///   the installed app, a visitor who has used it here before) and opens
///   it in place from the page's buttons and example links;
/// - on every page and in the app it loads Google Analytics with its
///   cookies (advertising always denied), and each start of the app is an
///   `app_start` event; no notice asks: Cookie settings, at the foot of the
///   pages, opens it, and its "Decline" deletes the statistics cookies and
///   stops loading them in this browser (consent-only statistics are not
///   reported by Google Analytics 4 below its modelling thresholds, so they
///   counted almost nobody);
/// - a new visitor arriving at a default address of the hosting project is
///   sent to the site's own address (whoever has projects stored there stays:
///   the storage belongs to the address).
String renderSiteScript() {
  final hosts = jsonEncode(['$firebaseProjectId.web.app', '$firebaseProjectId.firebaseapp.com']);
  final origin = jsonEncode(Uri.parse(siteUrl).origin);
  return '''// OpenCADIrrigation: the script of the site's pages. Generated by tool/gen_site.dart from tool/site.dart; do not edit by hand.
(function () {
  'use strict';
  var script = document.currentScript;
  var analyticsId = (script && script.getAttribute('data-ga')) || '';
  // Keys of the app's own storage (lib/app/io/prefs_web.dart): there once the app has run in this browser.
  var prefix = 'opencadirrigation.';
  // The answer to the notice; not under the app's prefix, since answering it is not using the app.
  var consentKey = 'oci-consent';
  var landing = document.getElementById('oci-landing');
  var status = document.getElementById('oci-status');
  var banner = document.getElementById('oci-consent');
  var started = false;
  var analytics = false;

  function usedHere() {
    try {
      for (var i = 0; i < localStorage.length; i++) {
        if (String(localStorage.key(i)).indexOf(prefix) === 0) return true;
      }
    } catch (e) {}
    return false;
  }

  // ---- the site's own address
  if ($hosts.indexOf(location.hostname) >= 0 && !usedHere()) {
    location.replace($origin + location.pathname + location.search + location.hash);
    return;
  }

  // ---- visit statistics: on every page and in the app, with their cookies, unless declined in Cookie settings
  // A "Decline" (Cookie settings, or the notice of version 1.6.0) is kept: no statistics in this browser.
  function declined() {
    try {
      var v = JSON.parse(localStorage.getItem(consentKey) || 'null');
      return !!v && v.c === 'denied';
    } catch (e) {
      return false;
    }
  }
  function saveConsent(c) {
    try { localStorage.setItem(consentKey, JSON.stringify({ c: c, t: Date.now() })); } catch (e) {}
  }
  function dropCookies() {
    var parts = location.hostname.split('.');
    var domains = ['', location.hostname, '.' + location.hostname];
    if (parts.length > 2) domains.push('.' + parts.slice(-2).join('.'));
    document.cookie.split(';').forEach(function (c) {
      var name = c.split('=')[0].trim();
      if (name !== '_ga' && name.indexOf('_ga_') !== 0) return;
      domains.forEach(function (d) {
        document.cookie = name + '=; Max-Age=0; path=/' + (d ? '; domain=' + d : '');
      });
    });
  }
  // the address without its fragment: a share link carries the whole project after the #
  function page() {
    return location.origin + location.pathname + location.search;
  }
  function loadAnalytics() {
    // not on this computer (development, tests): only the published site is counted
    if (analytics || !analyticsId || declined() || /^(localhost|127\\.0\\.0\\.1|\\[::1\\])\$/.test(location.hostname)) return;
    analytics = true;
    window.dataLayer = window.dataLayer || [];
    window.gtag = function () { window.dataLayer.push(arguments); };
    // the statistics with their cookies, advertising always off
    window.gtag('consent', 'default', { ad_storage: 'denied', ad_user_data: 'denied', ad_personalization: 'denied', analytics_storage: 'granted' });
    window.gtag('js', new Date());
    window.gtag('config', analyticsId, { page_location: page() });
    var tag = document.createElement('script');
    tag.async = true;
    tag.src = 'https://www.googletagmanager.com/gtag/js?id=' + encodeURIComponent(analyticsId);
    document.head.appendChild(tag);
  }
  function track(name) {
    if (analytics && !declined()) window.gtag('event', name, { page_location: page() });
  }
  function showBanner(show) {
    if (banner) banner.hidden = !show;
  }
  function choose(c) {
    saveConsent(c);
    showBanner(false);
    if (c === 'granted') {
      window['ga-disable-' + analyticsId] = false;
      if (analytics) window.gtag('consent', 'update', { analytics_storage: 'granted' });
      else loadAnalytics();
      return;
    }
    // declined: nothing more from this page, nothing loaded in the next ones, and the cookies deleted
    window['ga-disable-' + analyticsId] = true;
    if (analytics) window.gtag('consent', 'update', { analytics_storage: 'denied' });
    dropCookies();
  }
  // the notice opens only from Cookie settings, at the foot of the pages: no page asks by itself
  document.addEventListener('click', function (e) {
    var t = e.target.closest ? e.target.closest('[data-consent], [data-consent-open]') : null;
    if (!t) return;
    e.preventDefault();
    if (t.hasAttribute('data-consent-open')) showBanner(true);
    else choose(t.getAttribute('data-consent'));
  });
  loadAnalytics();

  // ---- the app, on an entry page
  function remember() {
    try { localStorage.setItem(prefix + 'site.app', '1'); } catch (e) {}
  }
  // The app starts by itself for an app address, the installed app and whoever has used it here before.
  function wanted() {
    if (/[?&](example|tutorial|design|ai|lang|source|app|share)=/.test(location.search)) return true;
    if (window.matchMedia && matchMedia('(display-mode: standalone), (display-mode: window-controls-overlay), (display-mode: minimal-ui), (display-mode: fullscreen)').matches) return true;
    return usedHere();
  }
  function start() {
    if (started) return;
    started = true;
    remember();
    showBanner(false);
    track('app_start');
    landing.className += ' oci-starting';
    status.textContent = landing.getAttribute('data-loading');
    // The engine, the app code and the fonts (those of other scripts and the symbols too,
    // under fonts/) come from this site and are fetched while the loader runs.
    var code = document.createElement('link');
    code.rel = 'preload';
    code.as = 'script';
    code.href = 'main.dart.js';
    document.head.appendChild(code);
    var boot = document.createElement('script');
    boot.src = 'flutter_bootstrap.js';
    boot.async = true;
    document.body.appendChild(boot);
    setTimeout(function () {
      if (!landing.hasAttribute('hidden')) status.textContent = landing.getAttribute('data-slow');
    }, 30000);
  }
  // The app buttons and example links open the app in this page (the app reads the query of the address);
  // opened in a new tab, the app starts there by itself.
  function onAppLink(e) {
    var a = e.target.closest ? e.target.closest('a[data-app]') : null;
    if (!a) return;
    remember();
    if (e.type !== 'click' || e.button !== 0 || e.ctrlKey || e.metaKey || e.shiftKey || e.altKey) return;
    e.preventDefault();
    history.replaceState(null, '', location.pathname + a.search);
    window.scrollTo(0, 0);
    start();
  }
  if (landing) {
    document.addEventListener('click', onAppLink);
    document.addEventListener('auxclick', onAppLink);
    window.addEventListener('flutter-first-frame', function () { landing.setAttribute('hidden', ''); });
    if (wanted()) start();
  }
})();
''';
}

/// sitemap.xml with the entry pages, their hreflang alternates and their
/// images (for image search): the screenshot and logo on the page, the
/// sharing image and the screenshot of the app manifest; then the legal
/// pages of the languages they are written in.
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
      for (final h in hreflangsOf(a)) {
        b.writeln('    <xhtml:link rel="alternate" hreflang="$h" href="${a.url}"/>');
      }
    }
    b.writeln('    <xhtml:link rel="alternate" hreflang="x-default" href="${siteLang('en').url}"/>');
    for (final image in [landingShot(landingShotWidths.last), landingLogo(landingLogoWidths.last), ogImage(l), 'screenshots/design-1440x900.png']) {
      b.writeln('    <image:image><image:loc>$siteUrl$image</image:loc></image:image>');
    }
    b.writeln('  </url>');
  }
  final translated = [
    for (final l in siteLanguages)
      if (hasLegalText(l.code)) l,
  ];
  for (final page in [privacyUrl, termsUrl]) {
    for (final l in translated) {
      b.writeln('  <url>');
      b.writeln('    <loc>${page(l)}</loc>');
      b.writeln('    <lastmod>$legalLastMod</lastmod>');
      b.writeln('    <changefreq>yearly</changefreq>');
      b.writeln('    <priority>0.3</priority>');
      for (final a in translated) {
        b.writeln('    <xhtml:link rel="alternate" hreflang="${a.tag}" href="${page(a)}"/>');
      }
      b.writeln('    <xhtml:link rel="alternate" hreflang="x-default" href="${page(siteLang('en'))}"/>');
      b.writeln('  </url>');
    }
  }
  // the user guide (tool/site_manual.dart): its chapters in English and Portuguese
  for (final (url, alternates) in manualSitemapEntries()) {
    b.writeln('  <url>');
    b.writeln('    <loc>$url</loc>');
    b.writeln('    <lastmod>$siteLastMod</lastmod>');
    b.writeln('    <changefreq>monthly</changefreq>');
    b.writeln('    <priority>0.6</priority>');
    for (final e in alternates.entries) {
      b.writeln('    <xhtml:link rel="alternate" hreflang="${e.key}" href="${e.value}"/>');
    }
    b.writeln('  </url>');
  }
  b.writeln('</urlset>');
  return b.toString();
}

/// The web app manifest of [lang]: `manifest.json` at the root (English)
/// and `<code>/manifest.json` beside every other entry page, with the same
/// identity (installing from /pt/ or from / is the same app), a start
/// address in that language (the app reads it from the path) and the names,
/// shortcuts and screenshot labels of that page.
String renderManifest(SiteLang lang) {
  final t = siteText(lang.code);
  // the root manifest keeps addresses relative to it (the root page may be served from a folder)
  final up = lang.isRoot ? '' : '../';
  SiteExample example(String id) => t.examples.firstWhere((e) => e.id == id);
  Map<String, Object> shortcut(String name, String? description, String query) => {
    'name': name,
    'description': ?description,
    'url': './?$query',
    'icons': [
      {'src': '${up}icons/Icon-192.png', 'sizes': '192x192'},
    ],
  };
  final manifest = {
    'name': 'OpenCADIrrigation — ${t.subCategory}',
    'short_name': 'OpenCADIrrig',
    'id': lang.isRoot ? './' : '/',
    'start_url': './?source=pwa',
    'scope': lang.isRoot ? './' : '../',
    'display': 'standalone',
    'display_override': ['window-controls-overlay', 'standalone', 'browser'],
    'orientation': 'any',
    'background_color': '#14171B',
    'theme_color': '#0D47A1',
    'lang': lang.tag,
    'dir': lang.dir,
    'description': t.description,
    'categories': ['productivity', 'utilities', 'education', 'business'],
    'prefer_related_applications': false,
    'icons': [
      for (final (src, size, purpose) in [
        ('icons/Icon-192.png', '192x192', 'any'),
        ('icons/Icon-512.png', '512x512', 'any'),
        ('icons/Icon-maskable-192.png', '192x192', 'maskable'),
        ('icons/Icon-maskable-512.png', '512x512', 'maskable'),
        ('brand/logo-mark-1024.png', '1024x1024', 'any'),
      ])
        {'src': '$up$src', 'sizes': size, 'type': 'image/png', 'purpose': purpose},
    ],
    'screenshots': [
      for (final (src, size, form) in manifestScreenshots) {'src': '$up$src', 'sizes': size, 'type': 'image/png', 'form_factor': form, 'label': t.screenshotLabel},
    ],
    'shortcuts': [
      shortcut(t.tutorial, null, 'tutorial=1'),
      shortcut(t.aiCta, t.aiTitle, 'ai=1'),
      shortcut(example('orchard').title, example('orchard').text, 'design=1'),
      shortcut(example('garden').title, example('garden').text, 'example=garden'),
      shortcut(example('pivot').title, example('pivot').text, 'example=pivot'),
    ],
    // the installed app as a program of the computer: "Open with" a project or a drawing, the window already open
    // focused (the app reads the launch from its queue, lib/app/io/launch_files.dart), and what is shared with it
    // (web/sw.js keeps it for the page)
    'file_handlers': [
      for (final accept in [manifestProjectTypes, manifestDrawingTypes])
        {
          'action': './?source=file',
          'accept': accept,
          'icons': [
            {'src': '${up}icons/Icon-192.png', 'sizes': '192x192', 'type': 'image/png'},
          ],
          'launch_type': 'single-client',
        },
    ],
    'launch_handler': {
      'client_mode': ['focus-existing', 'auto'],
    },
    'share_target': {
      'action': './share-target',
      'method': 'POST',
      'enctype': 'multipart/form-data',
      'params': {
        'title': 'title',
        'text': 'text',
        'url': 'url',
        'files': [
          {'name': 'files', 'accept': manifestShareAccept},
        ],
      },
    },
  };
  return '${const JsonEncoder.withIndent('  ').convert(manifest)}\n';
}

/// The project files the installed app opens with "Open with" (a file handler of the manifests), by MIME type
/// (the systems register them by extension): a `.json` opens as a project when its "format" says so, and is
/// imported otherwise (lib/app/launch_actions.dart).
const manifestProjectTypes = {
  'application/json': ['.oci.json', '.json'],
};

/// The drawings, maps and surveys it imports the same way.
const manifestDrawingTypes = {
  'image/vnd.dxf': ['.dxf'],
  'image/vnd.dwg': ['.dwg'],
  'image/vnd.dgn': ['.dgn'],
  'application/vnd.google-earth.kml+xml': ['.kml'],
  'application/vnd.google-earth.kmz': ['.kmz'],
  'application/geo+json': ['.geojson'],
  'application/gpx+xml': ['.gpx'],
  'application/vnd.las': ['.las', '.laz'],
};

/// What may be shared with the installed app (its share target): pictures, PDF plans, projects, drawings, maps,
/// surveys and point files (types and extensions: phones share many of these files without a type of their own).
const manifestShareAccept = [
  'image/*',
  'application/pdf',
  'application/json',
  'application/zip',
  'text/csv',
  'text/plain',
  'application/octet-stream',
  '.oci.json',
  '.json',
  '.dxf',
  '.dwg',
  '.dgn',
  '.kml',
  '.kmz',
  '.geojson',
  '.gpx',
  '.shp',
  '.zip',
  '.las',
  '.laz',
  '.csv',
  '.txt',
  '.pdf',
];

/// Screenshots of the app in the manifests: `(path, size, form factor)`;
/// the narrow one lets phones show the full install sheet.
const manifestScreenshots = [('screenshots/design-1440x900.png', '1440x900', 'wide'), ('screenshots/phone-780x1688.png', '780x1688', 'narrow')];

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
Source code: $appRepositoryUrl (MIT licence)

/* SITE */
Last update: $siteLastMod
Version: $appVersion
Standards: HTML5, CSS3, JavaScript, WebAssembly (Flutter web)
Languages: $languages
Pages: generated by tool/gen_site.dart
For language models: ${siteUrl}llms.txt, ${siteUrl}llms-full.txt
''';
}

/// 404 page (Firebase Hosting serves it, with status 404, for every path
/// that is not a file: firebase.json has no catch-all rewrite): not indexed. It
/// shows the message in English, or in the first browser language the site
/// speaks, and links to every entry page.
String render404() {
  final b = StringBuffer()
    ..writeln('''<!DOCTYPE html>
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
  b.writeln(
    '    <nav aria-label="Languages">${[for (final l in siteLanguages) '<a href="${l.url}" hreflang="${l.tag}" lang="${l.tag}" dir="${l.dir}">${languageNames[l.code]}</a>'].join(' · ')}</nav>',
  );
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
  for (final l in siteLanguages) '${l.path}manifest.json': renderManifest(l),
  for (final l in siteLanguages) '${l.path}privacy/index.html': renderLegalPage(l, privacy: true),
  for (final l in siteLanguages) '${l.path}terms/index.html': renderLegalPage(l, privacy: false),
  // the user guide, from docs/manual (English) and docs/manual/pt-BR
  ...renderManualPages(),
  'site.js': renderSiteScript(),
  '.well-known/security.txt': renderSecurityTxt(),
  'en/index.html': renderLegacyEnRedirect(),
  'sitemap.xml': renderSitemap(),
  '404.html': render404(),
  'robots.txt': renderRobots(),
  'humans.txt': renderHumans(),
  'llms.txt': renderLlmsTxt(),
  'llms-full.txt': renderLlmsFullTxt(),
  '$indexNowKey.txt': indexNowKey,
};

/// security.txt (RFC 9116): where to report a vulnerability privately
/// (SECURITY.md), valid for a year after the site's last update, so every
/// release renews it.
String renderSecurityTxt() {
  final expires = DateTime.parse(siteLastMod).add(const Duration(days: 365)).toIso8601String().substring(0, 10);
  return [
    'Contact: $appRepositoryUrl/security/advisories/new',
    'Expires: ${expires}T00:00:00.000Z',
    'Preferred-Languages: en, pt, es',
    'Canonical: $siteUrl.well-known/security.txt',
    'Policy: $appRepositoryUrl/blob/main/SECURITY.md',
    '',
  ].join('\n');
}

/// Files generated outside `web/`, by path from the repository root: the
/// hosting configuration (see hosting/README.md).
Map<String, String> renderRepositoryFiles() => {'hosting/firebase.json': renderHostingConfig()};

/// Cache rule of the hosting: a month for the images whose addresses carry
/// their version (`?v=`) or never change, and a revalidation (`no-cache`,
/// a cheap 304 when unchanged) for every file of the app whose name stays
/// the same from build to build, so that a browser without the service
/// worker never mixes two builds.
const _monthCache = 'public, max-age=2592000';
const _revalidate = 'no-cache';

/// Permissions the pages may ask for: the device position (GPS walks and
/// stake-out) and the microphone (voice dictation of the AI assistant) on
/// the site itself; nothing else.
const permissionsPolicy = 'camera=(), microphone=(self), geolocation=(self), payment=(), usb=(), serial=(), hid=(), bluetooth=(), browsing-topics=()';

/// What `firebase deploy` checks first, in the deploy folder (1.6.0): the build was made by tool/build_web.sh, not a
/// plain `flutter build web`: the offline worker, its registration and the address of the fonts filled in (no
/// `__OCI_` placeholder left) and the fonts the site serves present.
const predeployCheck = 'test -f public/sw.js && test -d public/fonts && ! grep -q __OCI_ public/sw.js public/offline.js public/flutter_bootstrap.js';

/// firebase.json for the site: security headers on every file, the cache
/// rules above, and the old English address answered by a permanent
/// redirect (the query, `?example=…`, is kept by the hosting). The default
/// addresses of the project cannot be redirected here (the rules do not see
/// the host): site.js sends new visitors from them to the site's address.
String renderHostingConfig() {
  Map<String, Object> rule(String source, Map<String, String> headers) => {
    'source': source,
    'headers': [
      for (final e in headers.entries) {'key': e.key, 'value': e.value},
    ],
  };
  final config = {
    'hosting': {
      'public': 'public',
      'predeploy': [predeployCheck],
      // the dot files of a build and of the system, not /.well-known/
      'ignore': ['firebase.json', '**/.DS_Store', '**/.last_build_id', '**/.git/**', '**/.firebase/**', '**/node_modules/**'],
      'redirects': [
        for (final source in ['/en', '/en/', '/en/index.html']) {'source': source, 'destination': '/', 'type': 301},
      ],
      'headers': [
        rule('**', {'X-Content-Type-Options': 'nosniff', 'X-Frame-Options': 'SAMEORIGIN', 'Referrer-Policy': 'strict-origin-when-cross-origin', 'Permissions-Policy': permissionsPolicy}),
        rule('/@(brand|icons|screenshots|og)/**', {'Cache-Control': _monthCache}),
        // the fallback fonts the site serves (tool/site_fonts.dart): their addresses carry their version
        rule('/fonts/**', {'Cache-Control': _monthCache}),
        rule('/*.@(png|ico)', {'Cache-Control': _monthCache}),
        rule('/', {'Cache-Control': _revalidate}),
        rule('/*/', {'Cache-Control': _revalidate}),
        rule('**/*.html', {'Cache-Control': _revalidate}),
        rule('**/manifest.json', {'Cache-Control': _revalidate}),
        // the pages of the user guide, asked for by their folder address (/manual/calculation/)
        rule('/manual/**', {'Cache-Control': _revalidate}),
        rule('/*/manual/**', {'Cache-Control': _revalidate}),
        rule('/@(flutter_bootstrap.js|flutter.js|version.json|sw.js|offline.js|site.js|main.dart.js|design_worker.js)', {'Cache-Control': _revalidate}),
        rule('/*.part.js', {'Cache-Control': _revalidate}),
        rule('/@(assets|canvaskit)/**', {'Cache-Control': _revalidate}),
      ],
    },
  };
  return '${const JsonEncoder.withIndent('  ').convert(config)}\n';
}
