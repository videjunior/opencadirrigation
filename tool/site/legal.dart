part of '../site.dart';

// The privacy policy, the terms of use and the consent notice of the site.
// Portuguese, English and Spanish are written here, the other 17 languages
// at the end of their tool/site/<code>.dart. A language without its own
// text would show the English one: its pages would then say lang="en", not
// be indexed and name the English page as canonical.
// The controller is "the maintainer of OpenCADIrrigation", reached through
// the issues of the repository.

/// Date of the current text of the legal pages (shown at their foot).
const legalLastMod = '2026-11-04';

/// Address where the maintainer is reached (the project's issues).
const contactUrl = '$appRepositoryUrl/issues';

/// A section of a legal page: a heading and its paragraphs; a paragraph
/// starting with "- " is an item of a list, and `[label](url)` is a link.
class LegalSection {
  const LegalSection(this.heading, this.body);
  final String heading;
  final List<String> body;
}

class LegalText {
  const LegalText({
    required this.privacyTitle,
    required this.privacyLead,
    required this.privacy,
    required this.termsTitle,
    required this.termsLead,
    required this.terms,
    required this.privacyLink,
    required this.termsLink,
    required this.cookieSettings,
    required this.consentText,
    required this.consentAccept,
    required this.consentDecline,
    required this.updated,
    required this.home,
  });
  final String privacyTitle;
  final String privacyLead;
  final List<LegalSection> privacy;
  final String termsTitle;
  final String termsLead;
  final List<LegalSection> terms;

  /// Footer links of every page.
  final String privacyLink;
  final String termsLink;

  /// The footer button that shows the consent notice again.
  final String cookieSettings;

  /// The statistics notice, opened by [cookieSettings]: what is counted
  /// and what declining does, then Decline and Accept (equal buttons) and
  /// the link to the privacy policy.
  final String consentText;
  final String consentAccept;
  final String consentDecline;

  /// "Last updated" before the date at the foot of a legal page.
  final String updated;

  /// Link from a legal page back to the entry page.
  final String home;
}

const _legalEn = LegalText(
  privacyTitle: 'Privacy policy',
  privacyLead: 'What OpenCADIrrigation keeps, what it sends and to whom, in plain words.',
  privacy: [
    LegalSection('Who is responsible', [
      'The site opencadirrigation.com and the OpenCADIrrigation app are published by the maintainer of OpenCADIrrigation, who is the controller of the personal data described on this page.',
      'Contact: open an issue in the repository of the project ([github.com/videjunior/opencadirrigation/issues]($contactUrl)). For a matter that should not be public, ask there for a private channel, without writing personal data in the issue.',
    ]),
    LegalSection('In short', [
      '- There is no account and no server of OpenCADIrrigation behind the app: projects, autosaves, versions, AI conversations, keys and preferences stay in your browser and in the files you save.',
      '- Visit statistics (Google Analytics) run on every page of the site and in the app, with their cookies; you can turn them off with Cookie settings, at the foot of the pages.',
      '- The services the app uses for fonts, maps, terrain, climate, address search and the AI assistant receive your requests straight from your browser when you use them.',
    ]),
    LegalSection('What stays on your device', [
      'The autosave, the recent projects, the last 10 versions of each project, the 24 most recent AI conversations (with their pictures and small attachments), the API keys you choose to remember, the Google Maps key, the interface language, the theme and the other preferences are kept in your browser\'s storage (localStorage and IndexedDB), and a copy of the app in its cache, so that it starts offline. Nobody else receives them, and we have no copy.',
      'They stay until you delete them: Keep conversations in this browser, in the assistant\'s settings, turns the conversations off and deletes them, and clearing the site data in the browser deletes everything. A browser may also delete them by itself when space runs short or, in Safari, after some weeks without a visit, so keep your projects as .oci.json files.',
      'A share link carries the project inside the address, after the #, which browsers do not send to any server.',
    ]),
    LegalSection('Visit statistics and cookies', [
      'Every page of the site and the app load Google Analytics 4, which sets the cookies _ga and _ga_<id> (they last up to two years) and records the pages viewed and each start of the app, the time of the visit, the page that brought you, the type of device and browser, the screen size, the language and an approximate location that Google derives from the IP address (Google Analytics 4 does not store the IP address). It never receives the part of the address after the #, where a share link carries the project, and its advertising functions are off.',
      'Purpose: to know how many people visit the site and use the app, and which pages and languages they use, so as to improve them. Legal basis: the legitimate interest in measuring the use of a free service. The data are kept for the retention period set in Google Analytics, at most 14 months.',
      'You can object at any time with Cookie settings, at the foot of the pages: if you decline, the statistics cookies of the site are deleted and Google Analytics is no longer loaded in that browser. Blocking cookies or scripts in your browser also stops it.',
      'The statistics also run while the app is open, in the page that holds your projects and, if you choose to remember them, your AI keys: like any script of the site, the Google Analytics script could read the storage of the site in your browser, and it sends Google only the data above. Google Analytics is a Google service under its own terms and privacy policy, and the data may be processed in the United States and in other countries.',
    ]),
    LegalSection('Hosting', [
      'The site is served by Firebase Hosting (Google), which receives the IP address and the technical data of each request (address asked for, browser, time) to deliver the pages and protect the service. Legal basis: the legitimate interest in running the site safely. These data are used for nothing else.',
      'The app and all its fonts, those of every script and symbol included (Chinese, Japanese, Arabic and Indian scripts, arrows, emoji), come from this site too: no font service is contacted.',
    ]),
    LegalSection('Services your browser contacts when you use them', [
      '- Base maps: OpenStreetMap, OpenTopoMap, CARTO, Esri, Google (with your own key) or the address you set receive the IP address and the map area on screen.',
      '- Online elevation and climate: Terrain Tiles (AWS Open Data), Open-Meteo, OpenTopoData and NASA POWER receive the coordinates of the area, nothing else of the project.',
      '- Address search: Nominatim (OpenStreetMap) receives the address you type.',
      '- Catalogues loaded by URL: the server of that address.',
      '- AI assistant (optional): Anthropic or OpenAI, with your own key. Nothing is sent before you press Send; then your message, the files you attach, the project data you tick, the earlier messages and, while it works, the results of the tools it uses, pictures of the drawing included. Your agreement with that company governs what it does with them, and it bills your account.',
      '- Voice dictation: the browser\'s speech recognition sends the sound to the browser maker (Google in Chrome, Microsoft in Edge, Apple in Safari).',
      'Each of these services has its own privacy policy and may process data outside your country.',
    ]),
    LegalSection('Your rights', [
      'Under the LGPD in Brazil, the GDPR in the European Union and the United Kingdom, and similar laws, you may ask for confirmation, access, correction, deletion and information about the sharing of your personal data, object to a processing and withdraw your consent.',
      'We hold no data that name you: the statistics are pseudonymous, and everything else is in your browser, under your control. For any request, use the contact above. You may also complain to your data protection authority (in Brazil, the ANPD).',
    ]),
    LegalSection('Changes', ['When this policy changes, the date at the foot of the page changes too.']),
  ],
  termsTitle: 'Terms of use',
  termsLead: 'OpenCADIrrigation is free software. Using it means accepting these terms.',
  terms: [
    LegalSection('The software', [
      'OpenCADIrrigation is free and open-source software under the MIT licence ([opensource.org/license/mit]($licenseUrl)). You may use it for any purpose, professional and commercial work included, and copy, change and distribute it under that licence. There is no fee and no account.',
    ]),
    LegalSection('A design aid: the professional signs the design', [
      'The app helps to draw, calculate and document irrigation systems. Its results (pipe sizes, pressures, flows, uniformity, schedules, bills of materials, quotes and reports, and the work of the AI assistant) depend on the data you enter, on catalogue and site data and on models that simplify reality, and they may contain errors.',
      'Check them before you use them. A design made with the app must be reviewed, approved and signed by a qualified professional, who takes the technical responsibility for it as the law of the place requires (in Brazil, with the corresponding ART).',
    ]),
    LegalSection('No warranty', [
      'The software is provided "as is", without warranty of any kind, express or implied, including the warranties of merchantability, fitness for a particular purpose and noninfringement. In no event shall the authors or copyright holders be liable for any claim, damages or other liability arising from the software or its use (the terms of the MIT licence).',
    ]),
    LegalSection('Data and services of others', [
      'Maps, imagery, elevation, climate, address search and the manufacturer catalogues come from third parties, under their own terms and licences (see Help → About in the app). Catalogue data are taken from published tables and may be out of date: confirm models, curves and prices with the current data sheets before buying.',
      'In professional work, use each source within its terms: Help → Terms of the data in the app says what the free use of each allows. Some free services are for non-commercial use only (the free Open-Meteo services and the CARTO base maps), so the app downloads the climate from NASA POWER and the elevation from Terrain Tiles by default; the OpenStreetMap Foundation\'s tile server forbids heavy use and downloading areas for offline use, so the map kept for the field uses only the tiles already shown. The sheets, the PDFs and the report carry the credit of every source: keep it when you deliver or publish the work.',
      'The optional AI assistant runs on your own account with Anthropic or OpenAI, under that company\'s terms, and that company bills the use. A model can be wrong: approve the changes it proposes knowingly and check its work.',
    ]),
    LegalSection('Your content', ['Your projects, drawings, images and files are yours: you are responsible for them and for having the right to use what you import.']),
    LegalSection('Contact', ['Questions and problems: [github.com/videjunior/opencadirrigation/issues]($contactUrl). How your data are treated: the privacy policy.']),
  ],
  privacyLink: 'Privacy',
  termsLink: 'Terms of use',
  cookieSettings: 'Cookie settings',
  consentText: 'The site and the app count visits with Google Analytics, which uses cookies. If you decline, your visits are no longer counted in this browser.',
  consentAccept: 'Accept',
  consentDecline: 'Decline',
  updated: 'Last updated',
  home: 'Go to OpenCADIrrigation',
);

const _legalPt = LegalText(
  privacyTitle: 'Política de privacidade',
  privacyLead: 'O que o OpenCADIrrigation guarda, o que envia e para quem, em palavras simples.',
  privacy: [
    LegalSection('Quem é o responsável', [
      'O site opencadirrigation.com e o aplicativo OpenCADIrrigation são publicados pelo mantenedor do OpenCADIrrigation, que é o controlador dos dados pessoais descritos nesta página.',
      'Contato: abra uma issue no repositório do projeto ([github.com/videjunior/opencadirrigation/issues]($contactUrl)). Para um assunto que não deva ser público, peça ali um canal privado, sem escrever dados pessoais na issue.',
    ]),
    LegalSection('Em resumo', [
      '- Não há conta nem servidor do OpenCADIrrigation por trás do app: projetos, autossalvamentos, versões, conversas da IA, chaves e preferências ficam no seu navegador e nos arquivos que você salva.',
      '- As estatísticas de visita (Google Analytics) rodam em todas as páginas do site e no app, com os seus cookies; você pode desligá-las em Preferências de cookies, no rodapé das páginas.',
      '- Os serviços que o app usa para fontes, mapas, terreno, clima, busca de endereços e o assistente de IA recebem os pedidos direto do seu navegador quando você os usa.',
    ]),
    LegalSection('O que fica no seu aparelho', [
      'O autossalvamento, os projetos recentes, as 10 últimas versões de cada projeto, as 24 conversas mais recentes da IA (com as imagens e os anexos pequenos), as chaves de API que você escolher lembrar, a chave do Google Maps, o idioma, o tema e as demais preferências ficam no armazenamento do navegador (localStorage e IndexedDB), e uma cópia do app fica no cache dele, para abrir sem internet. Ninguém mais os recebe, e nós não temos cópia.',
      'Eles ficam até você apagá-los: Guardar as conversas neste navegador, nas configurações do assistente, desliga e apaga as conversas, e limpar os dados do site no navegador apaga tudo. O navegador também pode apagá-los sozinho quando falta espaço ou, no Safari, depois de algumas semanas sem visita; por isso guarde os projetos em arquivos .oci.json.',
      'Um link de compartilhamento leva o projeto dentro do endereço, depois do #, que os navegadores não enviam a nenhum servidor.',
    ]),
    LegalSection('Estatísticas de visita e cookies', [
      'Todas as páginas do site e o app carregam o Google Analytics 4, que grava os cookies _ga e _ga_<id> (duram até dois anos) e registra as páginas vistas e cada abertura do app, a hora da visita, a página de onde você veio, o tipo de aparelho e de navegador, o tamanho da tela, o idioma e uma localização aproximada que o Google deduz do endereço IP (o Google Analytics 4 não guarda o endereço IP). Ele nunca recebe a parte do endereço depois do #, onde um link de compartilhamento leva o projeto, e as suas funções de publicidade ficam desligadas.',
      'Finalidade: saber quantas pessoas visitam o site e usam o app, e quais páginas e idiomas usam, para melhorá-los. Base legal: o interesse legítimo em medir o uso de um serviço gratuito. Os dados ficam guardados pelo prazo de retenção configurado no Google Analytics, no máximo 14 meses.',
      'Você pode se opor a qualquer momento em Preferências de cookies, no rodapé das páginas: se recusar, os cookies de estatística do site são apagados e o Google Analytics deixa de ser carregado naquele navegador. Bloquear cookies ou scripts no seu navegador também o impede.',
      'As estatísticas rodam também com o app aberto, na página que guarda os seus projetos e, se você escolher lembrá-las, as suas chaves de IA: como qualquer script do site, o script do Google Analytics poderia ler o armazenamento do site no seu navegador, e ele envia ao Google só os dados acima. O Google Analytics é um serviço do Google, com termos e política de privacidade próprios, e os dados podem ser tratados nos Estados Unidos e em outros países.',
    ]),
    LegalSection('Hospedagem', [
      'O site é servido pelo Firebase Hosting (Google), que recebe o endereço IP e os dados técnicos de cada requisição (endereço pedido, navegador, hora) para entregar as páginas e proteger o serviço. Base legal: o legítimo interesse em manter o site funcionando com segurança. Esses dados não são usados para mais nada.',
      'O app e todas as suas fontes, inclusive as de todas as escritas e símbolos (chinês, japonês, árabe, escritas indianas, setas, emoji), também vêm deste site: nenhum serviço de fontes é acessado.',
    ]),
    LegalSection('Serviços que o seu navegador acessa quando você os usa', [
      '- Mapas base: OpenStreetMap, OpenTopoMap, CARTO, Esri, Google (com a sua própria chave) ou o endereço que você configurar recebem o endereço IP e a área do mapa na tela.',
      '- Elevação e clima online: Terrain Tiles (AWS Open Data), Open-Meteo, OpenTopoData e NASA POWER recebem as coordenadas da área, nada mais do projeto.',
      '- Busca de endereços: o Nominatim (OpenStreetMap) recebe o endereço que você digita.',
      '- Catálogos carregados por URL: o servidor desse endereço.',
      '- Assistente de IA (opcional): Anthropic ou OpenAI, com a sua própria chave. Nada é enviado antes de você clicar em Enviar; então vão a sua mensagem, os arquivos anexados, os dados do projeto que você marcar, as mensagens anteriores e, enquanto ele trabalha, os resultados das ferramentas que usa, inclusive imagens do desenho. O seu contrato com essa empresa rege o que ela faz com esses dados, e ela cobra o uso na sua conta.',
      '- Ditado por voz: o reconhecimento de fala do navegador envia o áudio para a empresa do navegador (Google no Chrome, Microsoft no Edge, Apple no Safari).',
      'Cada um desses serviços tem a sua própria política de privacidade e pode tratar dados fora do seu país.',
    ]),
    LegalSection('Os seus direitos', [
      'Pela LGPD no Brasil, pelo GDPR na União Europeia e no Reino Unido e por leis semelhantes, você pode pedir confirmação, acesso, correção, eliminação e informação sobre o compartilhamento dos seus dados pessoais, opor-se a um tratamento e revogar o seu consentimento.',
      'Não guardamos dados que identifiquem você pelo nome: as estatísticas são pseudônimas, e todo o resto está no seu navegador, sob o seu controle. Para qualquer pedido, use o contato acima. Você também pode reclamar à autoridade de proteção de dados (no Brasil, a ANPD).',
    ]),
    LegalSection('Alterações', ['Quando esta política mudar, a data no rodapé da página muda também.']),
  ],
  termsTitle: 'Termos de uso',
  termsLead: 'O OpenCADIrrigation é software livre. Usá-lo significa aceitar estes termos.',
  terms: [
    LegalSection('O software', [
      'O OpenCADIrrigation é software livre e de código aberto, sob a licença MIT ([opensource.org/license/mit]($licenseUrl)). Você pode usá-lo para qualquer finalidade, inclusive trabalho profissional e comercial, e copiá-lo, alterá-lo e distribuí-lo nos termos dessa licença. Não há cobrança nem conta.',
    ]),
    LegalSection('Uma ferramenta de apoio: quem assina o projeto é o profissional', [
      'O app ajuda a desenhar, calcular e documentar sistemas de irrigação. Os resultados (diâmetros, pressões, vazões, uniformidade, turnos, listas de materiais, orçamentos e relatórios, e o trabalho do assistente de IA) dependem dos dados informados, dos dados de catálogo e do local e de modelos que simplificam a realidade, e podem conter erros.',
      'Confira-os antes de usá-los. Um projeto feito com o app deve ser revisado, aprovado e assinado por um profissional habilitado, que assume a responsabilidade técnica por ele conforme a lei do lugar (no Brasil, com a respectiva ART).',
    ]),
    LegalSection('Sem garantia', [
      'O software é fornecido "no estado em que se encontra", sem garantia de nenhum tipo, expressa ou implícita, inclusive de comercialização, de adequação a uma finalidade específica e de não violação. Em nenhum caso os autores ou titulares dos direitos autorais serão responsáveis por qualquer reclamação, dano ou outra responsabilidade decorrente do software ou do seu uso (os termos da licença MIT).',
    ]),
    LegalSection('Dados e serviços de terceiros', [
      'Mapas, imagens, elevação, clima, busca de endereços e os catálogos de fabricantes vêm de terceiros, com termos e licenças próprios (veja Ajuda → Sobre no app). Os dados de catálogo são tirados das tabelas publicadas e podem estar desatualizados: confirme modelos, curvas e preços nas folhas de dados atuais antes de comprar.',
      'No trabalho profissional, use cada fonte dentro dos seus termos: Ajuda → Termos dos dados, no app, diz o que o uso gratuito de cada uma permite. Alguns serviços gratuitos são só para uso não comercial (os serviços gratuitos do Open-Meteo e os mapas base da CARTO), por isso o app baixa o clima do NASA POWER e a elevação do Terrain Tiles por padrão; o servidor de blocos da Fundação OpenStreetMap proíbe o uso intenso e o download de áreas para uso off-line, por isso o mapa guardado para o campo usa só os blocos já mostrados. As pranchas, os PDFs e o relatório levam o crédito de cada fonte: mantenha-o ao entregar ou publicar o trabalho.',
      'O assistente de IA, opcional, funciona com a sua própria conta na Anthropic ou na OpenAI, sob os termos dessa empresa, que cobra o uso. Um modelo pode errar: aprove com consciência as alterações que ele propõe e confira o trabalho dele.',
    ]),
    LegalSection('O seu conteúdo', ['Os seus projetos, desenhos, imagens e arquivos são seus: você responde por eles e por ter o direito de usar o que importa.']),
    LegalSection('Contato', ['Dúvidas e problemas: [github.com/videjunior/opencadirrigation/issues]($contactUrl). Como os seus dados são tratados: a política de privacidade.']),
  ],
  privacyLink: 'Privacidade',
  termsLink: 'Termos de uso',
  cookieSettings: 'Preferências de cookies',
  consentText: 'O site e o app contam as visitas com o Google Analytics, que usa cookies. Se você recusar, as suas visitas deixam de ser contadas neste navegador.',
  consentAccept: 'Aceitar',
  consentDecline: 'Recusar',
  updated: 'Atualizado em',
  home: 'Ir para o OpenCADIrrigation',
);

const _legalEs = LegalText(
  privacyTitle: 'Política de privacidad',
  privacyLead: 'Qué guarda OpenCADIrrigation, qué envía y a quién, en palabras sencillas.',
  privacy: [
    LegalSection('Quién es el responsable', [
      'El sitio opencadirrigation.com y la aplicación OpenCADIrrigation los publica el mantenedor de OpenCADIrrigation, que es el responsable del tratamiento de los datos personales descritos en esta página.',
      'Contacto: abra una issue en el repositorio del proyecto ([github.com/videjunior/opencadirrigation/issues]($contactUrl)). Para un asunto que no deba ser público, pida allí un canal privado, sin escribir datos personales en la issue.',
    ]),
    LegalSection('En resumen', [
      '- No hay cuenta ni servidor de OpenCADIrrigation detrás de la aplicación: proyectos, guardados automáticos, versiones, conversaciones de la IA, claves y preferencias quedan en su navegador y en los archivos que usted guarda.',
      '- Las estadísticas de visitas (Google Analytics) se ejecutan en todas las páginas del sitio y en la aplicación, con sus cookies; puede desactivarlas en Preferencias de cookies, al pie de las páginas.',
      '- Los servicios que la aplicación usa para fuentes, mapas, terreno, clima, búsqueda de direcciones y el asistente de IA reciben las peticiones directamente desde su navegador cuando usted los usa.',
    ]),
    LegalSection('Lo que queda en su dispositivo', [
      'El guardado automático, los proyectos recientes, las 10 últimas versiones de cada proyecto, las 24 conversaciones más recientes de la IA (con sus imágenes y adjuntos pequeños), las claves de API que decida recordar, la clave de Google Maps, el idioma, el tema y las demás preferencias se guardan en el almacenamiento del navegador (localStorage e IndexedDB), y una copia de la aplicación en su caché, para abrir sin conexión. Nadie más los recibe, y nosotros no tenemos copia.',
      'Se conservan hasta que usted los borre: Guardar las conversaciones en este navegador, en los ajustes del asistente, desactiva y borra las conversaciones, y borrar los datos del sitio en el navegador lo elimina todo. El navegador también puede borrarlos por sí solo cuando falta espacio o, en Safari, tras algunas semanas sin visitas; por eso guarde sus proyectos en archivos .oci.json.',
      'Un enlace para compartir lleva el proyecto dentro de la dirección, después del #, que los navegadores no envían a ningún servidor.',
    ]),
    LegalSection('Estadísticas de visitas y cookies', [
      'Todas las páginas del sitio y la aplicación cargan Google Analytics 4, que guarda las cookies _ga y _ga_<id> (duran hasta dos años) y registra las páginas vistas y cada apertura de la aplicación, la hora de la visita, la página de la que vino, el tipo de dispositivo y de navegador, el tamaño de la pantalla, el idioma y una ubicación aproximada que Google deduce de la dirección IP (Google Analytics 4 no guarda la dirección IP). Nunca recibe la parte de la dirección después del #, donde un enlace para compartir lleva el proyecto, y sus funciones de publicidad están desactivadas.',
      'Finalidad: saber cuántas personas visitan el sitio y usan la aplicación, y qué páginas e idiomas usan, para mejorarlos. Base jurídica: el interés legítimo en medir el uso de un servicio gratuito. Los datos se conservan durante el plazo de retención configurado en Google Analytics, como máximo 14 meses.',
      'Puede oponerse en cualquier momento en Preferencias de cookies, al pie de las páginas: si lo rechaza, se borran las cookies de estadísticas del sitio y Google Analytics deja de cargarse en ese navegador. Bloquear las cookies o los scripts en su navegador también lo impide.',
      'Las estadísticas también se ejecutan con la aplicación abierta, en la página que guarda sus proyectos y, si decide recordarlas, sus claves de IA: como cualquier script del sitio, el script de Google Analytics podría leer el almacenamiento del sitio en su navegador, y solo envía a Google los datos anteriores. Google Analytics es un servicio de Google, con sus propios términos y política de privacidad, y los datos pueden tratarse en Estados Unidos y en otros países.',
    ]),
    LegalSection('Alojamiento', [
      'El sitio lo sirve Firebase Hosting (Google), que recibe la dirección IP y los datos técnicos de cada petición (dirección pedida, navegador, hora) para entregar las páginas y proteger el servicio. Base jurídica: el interés legítimo en mantener el sitio funcionando con seguridad. Estos datos no se usan para nada más.',
      'La aplicación y todas sus fuentes, incluidas las de todas las escrituras y símbolos (chino, japonés, árabe, escrituras indias, flechas, emoji), también vienen de este sitio: no se contacta ningún servicio de fuentes.',
    ]),
    LegalSection('Servicios a los que su navegador accede cuando usted los usa', [
      '- Mapas base: OpenStreetMap, OpenTopoMap, CARTO, Esri, Google (con su propia clave) o la dirección que usted configure reciben la dirección IP y el área del mapa en pantalla.',
      '- Elevación y clima en línea: Terrain Tiles (AWS Open Data), Open-Meteo, OpenTopoData y NASA POWER reciben las coordenadas del área, nada más del proyecto.',
      '- Búsqueda de direcciones: Nominatim (OpenStreetMap) recibe la dirección que usted escribe.',
      '- Catálogos cargados por URL: el servidor de esa dirección.',
      '- Asistente de IA (opcional): Anthropic u OpenAI, con su propia clave. No se envía nada antes de que pulse Enviar; entonces van su mensaje, los archivos adjuntos, los datos del proyecto que marque, los mensajes anteriores y, mientras trabaja, los resultados de las herramientas que usa, imágenes del dibujo incluidas. Su contrato con esa empresa rige lo que hace con esos datos, y ella factura el uso en su cuenta.',
      '- Dictado por voz: el reconocimiento de voz del navegador envía el audio a la empresa del navegador (Google en Chrome, Microsoft en Edge, Apple en Safari).',
      'Cada uno de estos servicios tiene su propia política de privacidad y puede tratar datos fuera de su país.',
    ]),
    LegalSection('Sus derechos', [
      'Según la LGPD en Brasil, el RGPD en la Unión Europea y el Reino Unido y leyes similares, usted puede pedir confirmación, acceso, rectificación, supresión e información sobre la comunicación de sus datos personales, oponerse a un tratamiento y retirar su consentimiento.',
      'No guardamos datos que lo identifiquen por su nombre: las estadísticas son seudónimas, y todo lo demás está en su navegador, bajo su control. Para cualquier petición, use el contacto de arriba. También puede reclamar ante su autoridad de protección de datos (en España, la AEPD; en Brasil, la ANPD).',
    ]),
    LegalSection('Cambios', ['Cuando esta política cambie, cambiará también la fecha al pie de la página.']),
  ],
  termsTitle: 'Términos de uso',
  termsLead: 'OpenCADIrrigation es software libre. Usarlo supone aceptar estos términos.',
  terms: [
    LegalSection('El software', [
      'OpenCADIrrigation es software libre y de código abierto, con licencia MIT ([opensource.org/license/mit]($licenseUrl)). Puede usarlo para cualquier fin, incluido el trabajo profesional y comercial, y copiarlo, modificarlo y distribuirlo según esa licencia. No hay pago ni cuenta.',
    ]),
    LegalSection('Una herramienta de apoyo: el proyecto lo firma el profesional', [
      'La aplicación ayuda a dibujar, calcular y documentar sistemas de riego. Sus resultados (diámetros, presiones, caudales, uniformidad, turnos, listas de materiales, presupuestos e informes, y el trabajo del asistente de IA) dependen de los datos introducidos, de los datos del catálogo y del sitio y de modelos que simplifican la realidad, y pueden contener errores.',
      'Revíselos antes de usarlos. Un proyecto hecho con la aplicación debe ser revisado, aprobado y firmado por un profesional habilitado, que asume su responsabilidad técnica según la ley del lugar.',
    ]),
    LegalSection('Sin garantía', [
      'El software se proporciona "tal cual", sin garantía de ningún tipo, expresa o implícita, incluidas las de comerciabilidad, idoneidad para un fin determinado y no infracción. En ningún caso los autores o titulares de los derechos de autor serán responsables de ninguna reclamación, daño u otra responsabilidad derivada del software o de su uso (los términos de la licencia MIT).',
    ]),
    LegalSection('Datos y servicios de terceros', [
      'Los mapas, las imágenes, la elevación, el clima, la búsqueda de direcciones y los catálogos de fabricantes provienen de terceros, con sus propios términos y licencias (vea Ayuda → Acerca de en la aplicación). Los datos de catálogo se toman de las tablas publicadas y pueden estar desactualizados: confirme modelos, curvas y precios en las fichas técnicas vigentes antes de comprar.',
      'En el trabajo profesional, use cada fuente dentro de sus términos: Ayuda → Términos de los datos, en la aplicación, dice lo que permite el uso gratuito de cada una. Algunos servicios gratuitos son solo para uso no comercial (los servicios gratuitos de Open-Meteo y los mapas base de CARTO), por eso la aplicación descarga el clima de NASA POWER y la elevación de Terrain Tiles por defecto; el servidor de teselas de la Fundación OpenStreetMap prohíbe el uso intensivo y la descarga de áreas para uso sin conexión, por eso el mapa guardado para el campo usa solo las teselas ya mostradas. Las láminas, los PDF y el informe llevan el crédito de cada fuente: consérvelo al entregar o publicar el trabajo.',
      'El asistente de IA, opcional, funciona con su propia cuenta en Anthropic u OpenAI, según los términos de esa empresa, que factura el uso. Un modelo puede equivocarse: apruebe con criterio los cambios que propone y revise su trabajo.',
    ]),
    LegalSection('Su contenido', ['Sus proyectos, dibujos, imágenes y archivos son suyos: usted responde por ellos y por tener derecho a usar lo que importa.']),
    LegalSection('Contacto', ['Dudas y problemas: [github.com/videjunior/opencadirrigation/issues]($contactUrl). Cómo se tratan sus datos: la política de privacidad.']),
  ],
  privacyLink: 'Privacidad',
  termsLink: 'Términos de uso',
  cookieSettings: 'Preferencias de cookies',
  consentText: 'El sitio y la aplicación cuentan las visitas con Google Analytics, que usa cookies. Si usted lo rechaza, sus visitas dejan de contarse en este navegador.',
  consentAccept: 'Aceptar',
  consentDecline: 'Rechazar',
  updated: 'Actualizado el',
  home: 'Ir a OpenCADIrrigation',
);

const _legalTexts = {
  'pt': _legalPt,
  'en': _legalEn,
  'es': _legalEs,
  // 1.6.0: the other 17 languages, written in tool/site/<code>.dart
  'zh': _legalZh,
  'hi': _legalHi,
  'ar': _legalAr,
  'fr': _legalFr,
  'bn': _legalBn,
  'ru': _legalRu,
  'ur': _legalUr,
  'id': _legalId,
  'de': _legalDe,
  'ja': _legalJa,
  'mr': _legalMr,
  'vi': _legalVi,
  'te': _legalTe,
  'ha': _legalHa,
  'tr': _legalTr,
  'pa': _legalPa,
  'sw': _legalSw,
};

/// Whether [code] has its own legal texts; the other languages show the
/// English ones until they are translated.
bool hasLegalText(String code) => _legalTexts.containsKey(code);

/// The legal texts of [code], the English ones when it has none yet.
LegalText legalText(String code) => _legalTexts[code] ?? _legalEn;

/// Address of the privacy policy of [lang] (`/privacy/`, `/pt/privacy/`…).
String privacyUrl(SiteLang lang) => '${lang.url}privacy/';

/// Address of the terms of use of [lang] (`/terms/`, `/pt/terms/`…).
String termsUrl(SiteLang lang) => '${lang.url}terms/';

/// [text] as HTML: escaped, with `[label](url)` written as a link.
String _inline(String text) {
  final out = StringBuffer();
  var at = 0;
  for (final m in RegExp(r'\[([^\]]+)\]\(([^)\s]+)\)').allMatches(text)) {
    out
      ..write(_esc(text.substring(at, m.start)))
      ..write('<a href="${_esc(m.group(2)!)}">${_esc(m.group(1)!)}</a>');
    at = m.end;
  }
  out.write(_esc(text.substring(at)));
  return out.toString();
}

/// The paragraphs of a section: runs of "- " items become one list.
String _legalBody(List<String> body) {
  final b = StringBuffer();
  var inList = false;
  for (final p in body) {
    final item = p.startsWith('- ');
    if (item && !inList) b.writeln('      <ul>');
    if (!item && inList) b.writeln('      </ul>');
    inList = item;
    b.writeln(item ? '        <li>${_inline(p.substring(2))}</li>' : '      <p>${_inline(p)}</p>');
  }
  if (inList) b.writeln('      </ul>');
  return b.toString();
}

const _legalStyle = '''
    html, body { margin: 0; min-height: 100%; background: #14171B; color: #CFD8DC; font: 16px/1.6 -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }
    main { max-width: 760px; margin: 0 auto; padding: 28px 20px 48px; }
    main a { color: #64B5F6; }
    .home img { width: min(320px, 70vw); height: auto; }
    h1 { color: #ECEFF1; font-size: clamp(1.5rem, 3.4vw, 2rem); line-height: 1.25; margin: 22px 0 6px; }
    h2 { color: #ECEFF1; font-size: 1.15rem; margin: 30px 0 8px; }
    .lead { color: #B0BEC5; font-size: 1.05rem; }
    ul { padding-inline-start: 1.3em; }
    li { margin: 6px 0; }
    footer { margin-top: 40px; padding-top: 16px; border-top: 1px solid #263238; color: #90A4AE; font-size: .92rem; line-height: 1.9; }
''';

/// The style of the consent notice and of the button that opens it again,
/// shared by the entry and the legal pages.
const _consentStyle = '''
    .oci-consent { position: fixed; z-index: 2147483001; inset-inline: 16px; bottom: 16px; max-width: 560px; margin-inline: auto; background: #1E2A38; color: #E3F2FD; border: 1px solid #2E4053; border-radius: 10px; padding: 14px 16px; box-shadow: 0 10px 30px rgba(0,0,0,.45); font-size: .95rem; }
    .oci-consent[hidden] { display: none; }
    .oci-consent p { margin: 0 0 10px; }
    .oci-consent a { color: #90CAF9; }
    .oci-consent .actions { display: flex; flex-wrap: wrap; gap: 10px; justify-content: flex-end; }
    .oci-consent button { font: inherit; font-weight: 600; min-width: 110px; padding: 8px 16px; border-radius: 8px; cursor: pointer; border: 1px solid #64B5F6; background: #14171B; color: #E3F2FD; }
    .oci-consent button:focus-visible, .oci-linkish:focus-visible { outline: 2px solid #90CAF9; outline-offset: 2px; }
    .oci-linkish { font: inherit; color: #64B5F6; background: none; border: 0; padding: 0; cursor: pointer; text-decoration: underline; }
''';

/// The statistics notice (hidden: the Cookie settings button at the foot of
/// the pages opens it), or nothing when the site counts no visits.
String consentNotice(SiteLang lang, LegalText l) {
  if (analyticsId.isEmpty) return '';
  final dir = hasLegalText(lang.code) ? lang.dirAttr : '';
  final tag = hasLegalText(lang.code) ? lang.tag : 'en';
  return '''
  <div class="oci-consent" id="oci-consent" role="region" aria-label="${_esc(l.cookieSettings)}" lang="$tag"$dir hidden>
    <p>${_esc(l.consentText)} <a href="${privacyUrl(lang)}">${_esc(l.privacyTitle)}</a></p>
    <div class="actions"><button type="button" data-consent="denied">${_esc(l.consentDecline)}</button><button type="button" data-consent="granted">${_esc(l.consentAccept)}</button></div>
  </div>''';
}

/// The footer links to the legal pages and to the consent notice.
String legalLinks(SiteLang lang) {
  final l = legalText(lang.code);
  return [
    '<a href="${privacyUrl(lang)}">${_esc(l.privacyLink)}</a>',
    '<a href="${termsUrl(lang)}">${_esc(l.termsLink)}</a>',
    if (analyticsId.isNotEmpty) '<button type="button" class="oci-linkish" data-consent-open>${_esc(l.cookieSettings)}</button>',
  ].join(' · ');
}

/// A legal page (the privacy policy or the terms of use) of [lang].
String renderLegalPage(SiteLang lang, {required bool privacy}) {
  final l = legalText(lang.code);
  final own = hasLegalText(lang.code);
  final english = siteLang('en');
  String urlOf(SiteLang x) => privacy ? privacyUrl(x) : termsUrl(x);
  final title = privacy ? l.privacyTitle : l.termsTitle;
  final lead = privacy ? l.privacyLead : l.termsLead;
  final sections = privacy ? l.privacy : l.terms;
  final translated = [
    for (final x in siteLanguages)
      if (hasLegalText(x.code)) x,
  ];
  final b = StringBuffer()
    ..writeln('<!DOCTYPE html>')
    ..writeln('<html lang="${own ? lang.tag : 'en'}">')
    ..writeln('<head>')
    ..writeln('  <!-- Generated by tool/gen_site.dart from tool/site.dart; do not edit by hand. -->')
    ..writeln('  <meta charset="UTF-8">')
    ..writeln('  <meta http-equiv="Content-Security-Policy" content="$contentSecurityPolicy">')
    ..writeln('  <meta name="viewport" content="width=device-width, initial-scale=1">')
    ..writeln('  <title>${_esc(title)} — OpenCADIrrigation</title>')
    ..writeln('  <meta name="description" content="${_esc(lead)}">')
    ..writeln('  <meta name="robots" content="${own ? 'index, follow' : 'noindex, follow'}">')
    ..writeln('  <link rel="canonical" href="${own ? urlOf(lang) : urlOf(english)}">');
  if (own) {
    for (final x in translated) {
      b.writeln('  <link rel="alternate" hreflang="${x.tag}" href="${urlOf(x)}">');
    }
    b.writeln('  <link rel="alternate" hreflang="x-default" href="${urlOf(english)}">');
  }
  b
    ..writeln('  <link rel="icon" href="/favicon.ico" sizes="any">')
    ..writeln('  <meta name="theme-color" content="#0D47A1">')
    ..writeln('  <meta name="color-scheme" content="dark">')
    ..write('  <style>\n$_legalStyle$_consentStyle  </style>\n')
    ..writeln('</head>')
    ..writeln('<body>')
    ..writeln('  <main${own ? lang.dirAttr : ''}>')
    ..writeln('    <p class="home"><a href="${lang.url}"><img src="/${landingLogo(landingLogoWidths.first)}" alt="OpenCADIrrigation" width="1040" height="349"></a></p>')
    ..writeln('    <h1>${_esc(title)}</h1>')
    ..writeln('    <p class="lead">${_esc(lead)}</p>');
  for (final s in sections) {
    b
      ..writeln('    <section>')
      ..writeln('      <h2>${_esc(s.heading)}</h2>')
      ..write(_legalBody(s.body))
      ..writeln('    </section>');
  }
  b
    ..writeln('    <footer>')
    ..writeln(
      '      <nav>${[for (final x in translated) x.code == (own ? lang.code : 'en') ? '<strong lang="${x.tag}">${languageNames[x.code]}</strong>' : '<a href="${urlOf(x)}" hreflang="${x.tag}" lang="${x.tag}">${languageNames[x.code]}</a>'].join(' · ')}</nav>',
    )
    ..writeln('      <p><a href="${lang.url}">${_esc(l.home)}</a> · ${legalLinks(lang)}</p>')
    ..writeln('      <p>${_esc(l.updated)} <time datetime="$legalLastMod">$legalLastMod</time></p>')
    ..writeln('    </footer>')
    ..writeln('  </main>')
    ..writeln(consentNotice(lang, l))
    ..writeln('  ${siteScriptTag()}')
    ..writeln('</body>')
    ..write('</html>');
  return b.toString();
}
