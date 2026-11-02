part of '../i18n.dart';

/// Strings added in 1.6.0 for site, PWA, translations and documentation: (pt, en, es), merged into the table after
/// the base strings (a key repeated in another part is a compile-time error).
const _sit = <String, (String, String, String)>{
  // Help → About: the legal pages of the site and the technical responsibility (SIT-01, SIT-13)
  'about.privacy': ('Política de privacidade', 'Privacy policy', 'Política de privacidad'),
  'about.terms': ('Termos de uso', 'Terms of use', 'Términos de uso'),
  'about.disclaimer': (
    'Ferramenta de apoio ao projeto: confira os resultados; o projeto deve ser revisado e assinado por um profissional habilitado.',
    'A design aid: check the results; the design must be reviewed and signed by a qualified professional.',
    'Herramienta de apoyo al proyecto: revise los resultados; el proyecto debe revisarlo y firmarlo un profesional habilitado.',
  ),
  // a newer build of the web app is installed while this page runs the older one (SIT-07)
  'update.ready': ('Há uma versão nova do OpenCADIrrigation pronta.', 'A new version of OpenCADIrrigation is ready.', 'Hay una versión nueva de OpenCADIrrigation lista.'),
  'update.reload': ('Recarregar', 'Reload', 'Recargar'),
  'update.later': ('Depois', 'Later', 'Más tarde'),
  'update.unsavedTitle': ('Recarregar agora?', 'Reload now?', '¿Recargar ahora?'),
  'update.unsaved': (
    'Há alterações não salvas. Elas ficam no autossalvamento deste navegador, e o app oferece recuperá-las quando abrir de novo; uma conversa da IA em andamento é interrompida.',
    'There are unsaved changes. They stay in this browser\'s autosave, and the app offers to recover them when it opens again; an AI conversation in progress is stopped.',
    'Hay cambios sin guardar. Quedan en el guardado automático de este navegador, y la aplicación ofrece recuperarlos cuando se abra de nuevo; una conversación de la IA en curso se interrumpe.',
  ),
  // ---- 1.6.0 SIT+: files opened with the installed app or shared with it (lib/app/launch_actions.dart)
  'launch.shareFailed': (
    'O que foi compartilhado com o OpenCADIrrigation não pôde ser lido (ou já foi aberto). Compartilhe de novo ou abra o arquivo pelo menu Arquivo.',
    'What was shared with OpenCADIrrigation could not be read (or was opened already). Share it again, or open the file from the File menu.',
    'Lo que se compartió con OpenCADIrrigation no se pudo leer (o ya se abrió). Compártalo de nuevo o abra el archivo desde el menú Archivo.',
  ),
  'launch.nothing': (
    'Nada do que foi compartilhado é um projeto, um desenho ou um link do OpenCADIrrigation.',
    'Nothing that was shared is a project, a drawing or an OpenCADIrrigation link.',
    'Nada de lo compartido es un proyecto, un dibujo o un enlace de OpenCADIrrigation.',
  ),
  // ---- 1.6.0 SIT+: third-party data in professional work (PRD-06): report table, Help → Terms of the data
  'reports.sources': ('Fontes de dados e créditos', 'Data sources and credits', 'Fuentes de datos y créditos'),
  'src.kind': ('Dado', 'Data', 'Dato'),
  'src.source': ('Fonte', 'Source', 'Fuente'),
  'src.credit': ('Crédito', 'Credit', 'Crédito'),
  'src.use': ('Uso gratuito', 'Free use', 'Uso gratuito'),
  'src.kind.elevation': ('Elevação', 'Elevation', 'Elevación'),
  'src.kind.climate': ('Clima', 'Climate', 'Clima'),
  'src.kind.baseMap': ('Mapa base', 'Base map', 'Mapa base'),
  'src.kind.search': ('Busca de endereços', 'Address search', 'Búsqueda de direcciones'),
  'src.use.any': ('Qualquer uso, com o crédito', 'Any use, with the credit', 'Cualquier uso, con el crédito'),
  'src.use.nonCommercial': (
    'Só uso não comercial: no trabalho profissional, use o plano pago do serviço ou outra fonte',
    'Non-commercial use only: for professional work, use the service\'s paid plan or another source',
    'Solo uso no comercial: en el trabajo profesional, use el plan de pago del servicio u otra fuente',
  ),
  'src.use.light': ('Só uso leve, sem uso intenso nem em massa', 'Light use only, no heavy or bulk use', 'Solo uso ligero, sin uso intensivo ni masivo'),
  'src.use.provider': ('Conforme os termos do provedor do mapa', 'As the terms of the map provider say', 'Según los términos del proveedor del mapa'),
  'terms.menu': ('Termos dos dados…', 'Terms of the data…', 'Términos de los datos…'),
  'terms.title': ('Termos dos dados de terceiros', 'Terms of the third-party data', 'Términos de los datos de terceros'),
  'terms.intro': (
    'Mapas, elevação, clima e busca de endereços vêm de serviços de terceiros, cada um com seus termos. As pranchas, os PDFs e o relatório levam o crédito de cada fonte usada no projeto: mantenha-o ao entregar ou publicar o trabalho. Alguns serviços gratuitos são só para uso não comercial; para o trabalho profissional, use as fontes livres para qualquer uso ou o plano pago do serviço.',
    'Maps, elevation, climate and address search come from third-party services, each with its own terms. The sheets, the PDFs and the report carry the credit of every source the project uses: keep it when you deliver or publish the work. Some free services are for non-commercial use only; for professional work, use the sources free for any use or the service\'s paid plan.',
    'Los mapas, la elevación, el clima y la búsqueda de direcciones vienen de servicios de terceros, cada uno con sus términos. Las láminas, los PDF y el informe llevan el crédito de cada fuente que usa el proyecto: consérvelo al entregar o publicar el trabajo. Algunos servicios gratuitos son solo para uso no comercial; para el trabajo profesional, use las fuentes libres para cualquier uso o el plan de pago del servicio.',
  ),
  'terms.used': ('Neste projeto', 'In this project', 'En este proyecto'),
  'terms.usedNone': (
    'Nenhum dado de terceiros (elevação online, clima baixado ou mapa guardado para o campo).',
    'No third-party data (online elevation, downloaded climate or map kept for the field).',
    'Ningún dato de terceros (elevación en línea, clima descargado o mapa guardado para el campo).',
  ),
  'terms.src.terrainTiles': (
    'Dados abertos (SRTM, GMTED, ETOPO1…) livres para qualquer uso, também comercial, com o crédito das fontes. É a fonte de elevação padrão.',
    'Open data (SRTM, GMTED, ETOPO1…) free for any use, commercial included, with the credit of the sources. The default elevation source.',
    'Datos abiertos (SRTM, GMTED, ETOPO1…) libres para cualquier uso, también comercial, con el crédito de las fuentes. Es la fuente de elevación por defecto.',
  ),
  'terms.src.openMeteoDem': (
    'A API gratuita do Open-Meteo é só para uso não comercial; o uso comercial pede uma chave do plano pago. Os dados (Copernicus DEM) pedem o crédito.',
    'The free Open-Meteo API is for non-commercial use only; commercial use needs a key of its paid plan. The data (Copernicus DEM) ask for the credit.',
    'La API gratuita de Open-Meteo es solo para uso no comercial; el uso comercial requiere una clave de su plan de pago. Los datos (Copernicus DEM) piden el crédito.',
  ),
  'terms.src.openTopoData': (
    'A API pública é para uso leve (até 1000 pedidos por dia, um por segundo); para uso intenso, instale um servidor próprio. Só na versão para computador.',
    'The public API is for light use (up to 1000 requests a day, one a second); for heavy use, run a server of your own. Desktop builds only.',
    'La API pública es para uso ligero (hasta 1000 peticiones al día, una por segundo); para uso intensivo, instale un servidor propio. Solo en la versión de escritorio.',
  ),
  'terms.src.nasaPower': (
    'Dados da NASA livres para qualquer uso, também comercial, com o agradecimento que a NASA pede. É a fonte de clima padrão para o trabalho profissional.',
    'NASA data free for any use, commercial included, with the acknowledgement NASA asks for. The default climate source for professional work.',
    'Datos de la NASA libres para cualquier uso, también comercial, con el agradecimiento que pide la NASA. Es la fuente de clima por defecto para el trabajo profesional.',
  ),
  'terms.src.openMeteo': (
    'A API gratuita é só para uso não comercial (até 10 000 pedidos por dia); o uso comercial pede uma chave do plano pago. Os dados (CC BY 4.0) pedem o crédito.',
    'The free API is for non-commercial use only (up to 10 000 requests a day); commercial use needs a key of its paid plan. The data (CC BY 4.0) ask for the credit.',
    'La API gratuita es solo para uso no comercial (hasta 10 000 peticiones al día); el uso comercial requiere una clave de su plan de pago. Los datos (CC BY 4.0) piden el crédito.',
  ),
  'terms.src.nominatim': (
    'Serviço mantido por voluntários: no máximo um pedido por segundo e nada de uso intenso; o app só busca o endereço digitado.',
    'A service run by volunteers: at most one request a second and no heavy use; the app only looks up the address you type.',
    'Servicio mantenido por voluntarios: como máximo una petición por segundo y nada de uso intensivo; la aplicación solo busca la dirección que usted escribe.',
  ),
  'clim.terms.nasaPower': (
    'NASA POWER: livre para qualquer uso, também no trabalho profissional, com o crédito.',
    'NASA POWER: free for any use, professional work included, with the credit.',
    'NASA POWER: libre para cualquier uso, también en el trabajo profesional, con el crédito.',
  ),
  'clim.terms.openMeteo': (
    'Open-Meteo: a API gratuita é só para uso não comercial. No trabalho profissional, use o NASA POWER (ou o plano pago do Open-Meteo).',
    'Open-Meteo: the free API is for non-commercial use only. For professional work, use NASA POWER (or Open-Meteo\'s paid plan).',
    'Open-Meteo: la API gratuita es solo para uso no comercial. En el trabajo profesional, use NASA POWER (o el plan de pago de Open-Meteo).',
  ),
  'ai.op.read_data_terms': ('Ler os termos dos dados de terceiros', 'Read the terms of the third-party data', 'Leer los términos de los datos de terceros'),
  // ---- 1.6.0 SIT+: the map of the area kept for the field (PRD-09)
  'fieldmap.menu': ('Guardar o mapa da área para o campo…', 'Keep the map of the area for the field…', 'Guardar el mapa del área para el campo…'),
  'fieldmap.title': ('Mapa da área para o campo', 'Map of the area for the field', 'Mapa del área para el campo'),
  'fieldmap.explain': (
    'Desenha o mapa base sob o projeto numa imagem guardada no projeto (camada de imagens), que fica no arquivo e na cópia deste navegador: no campo, sem rede, o mapa continua lá. Só o que os termos do provedor permitem.',
    'Draws the base map under the project into a picture kept in the project (images layer), saved in the file and in this browser\'s copy: in the field, with no network, the map is still there. Only what the terms of the provider allow.',
    'Dibuja el mapa base bajo el proyecto en una imagen guardada en el proyecto (capa de imágenes), que queda en el archivo y en la copia de este navegador: en el campo, sin red, el mapa sigue ahí. Solo lo que permiten los términos del proveedor.',
  ),
  'fieldmap.how.seen': (
    '{m}: só os blocos que esta página já mostrou ({n} guardados); nenhum outro é baixado, porque a política do provedor não permite baixar áreas para uso off-line. Antes, aproxime e percorra a área no detalhe que quiser; o que nunca apareceu fica em branco.',
    '{m}: only the tiles this page has already shown ({n} kept); no other is downloaded, since the provider\'s policy does not allow downloading areas for offline use. First zoom in and pan over the area at the detail you want; what was never shown stays white.',
    '{m}: solo las teselas que esta página ya mostró ({n} guardadas); no se descarga ninguna otra, porque la política del proveedor no permite descargar áreas para uso sin conexión. Antes, acérquese y recorra el área con el detalle que desee; lo que nunca apareció queda en blanco.',
  ),
  'fieldmap.how.download': (
    '{m}: o seu próprio servidor de blocos; os blocos da área são baixados (até 400).',
    '{m}: your own tile server; the tiles of the area are downloaded (up to 400).',
    '{m}: su propio servidor de teselas; se descargan las teselas del área (hasta 400).',
  ),
  'fieldmap.tip': (
    'Salve o projeto (Ctrl+S) e abra o arquivo no celular ou tablet que vai a campo. A sua ortofoto ou imagem de drone importada já funciona sem rede.',
    'Save the project (Ctrl+S) and open the file on the phone or tablet that goes to the field. Your own orthophoto or drone image, once imported, already works with no network.',
    'Guarde el proyecto (Ctrl+S) y abra el archivo en el teléfono o la tableta que va al campo. Su propia ortofoto o imagen de dron, una vez importada, ya funciona sin red.',
  ),
  'fieldmap.keep': ('Guardar o mapa', 'Keep the map', 'Guardar el mapa'),
  'fieldmap.done': ('Mapa {m} da área guardado no projeto ({n} blocos).', 'The {m} map of the area is kept in the project ({n} tiles).', 'Mapa {m} del área guardado en el proyecto ({n} teselas).'),
  'fieldmap.missing': ('{n} lugares nunca mostrados ficaram em branco.', '{n} places never shown stayed white.', '{n} lugares nunca mostrados quedaron en blanco.'),
  'fieldmap.name': ('Mapa para o campo ({m})', 'Map for the field ({m})', 'Mapa para el campo ({m})'),
  'fieldmap.err.noGeo': (
    'O projeto não está georreferenciado: defina o local (Arquivo → Georreferência) e escolha um mapa base.',
    'The project is not georeferenced: set the site (File → Georeference) and pick a base map.',
    'El proyecto no está georreferenciado: defina el sitio (Archivo → Georreferencia) y elija un mapa base.',
  ),
  'fieldmap.err.noMap': ('Escolha antes um mapa base (Ver → Mapa base).', 'Pick a base map first (View → Base map).', 'Elija antes un mapa base (Ver → Mapa base).'),
  'fieldmap.err.google': (
    'Os termos do Google não permitem guardar os mapas dele. Use outro mapa base, a sua ortofoto ou o seu próprio servidor de blocos.',
    'The Google terms do not allow keeping its maps. Use another base map, your own orthophoto or your own tile server.',
    'Los términos de Google no permiten guardar sus mapas. Use otro mapa base, su propia ortofoto o su propio servidor de teselas.',
  ),
  'fieldmap.err.busy': ('Um cálculo está em andamento: espere terminar.', 'A design is running: wait until it finishes.', 'Hay un cálculo en curso: espere a que termine.'),
  'fieldmap.err.noArea': ('Não há área para o mapa: desenhe o projeto ou enquadre a área na tela.', 'There is no area for the map: draw the project or frame the area on screen.', 'No hay área para el mapa: dibuje el proyecto o encuadre el área en la pantalla.'),
  'fieldmap.err.notSeen': (
    'Esta página ainda não mostrou blocos do mapa nesta área: aproxime e percorra a área com o mapa base visível e tente de novo.',
    'This page has not shown map tiles over this area yet: zoom in and pan over the area with the base map on, then try again.',
    'Esta página aún no mostró teselas del mapa en esta área: acérquese y recorra el área con el mapa base visible e intente de nuevo.',
  ),
  'fieldmap.err.download': (
    'Os blocos do seu servidor não puderam ser baixados (sem rede ou modelo inválido).',
    'The tiles of your server could not be downloaded (no network, or an invalid template).',
    'No se pudieron descargar las teselas de su servidor (sin red o plantilla no válida).',
  ),
  'fieldmap.policy.seen': ('só os blocos já mostrados por esta página, nenhum baixado', 'only the tiles this page has already shown, none downloaded', 'solo las teselas que esta página ya mostró, ninguna descargada'),
  'fieldmap.policy.download': ('os blocos da área baixados do servidor do próprio usuário', 'the tiles of the area downloaded from the user\'s own server', 'las teselas del área descargadas del servidor del propio usuario'),
  'fieldmap.policy.refused': ('nada (sem mapa base, ou termos que não permitem)', 'nothing (no base map, or terms that do not allow it)', 'nada (sin mapa base, o términos que no lo permiten)'),
  'hist.fieldMap': ('Mapa guardado para o campo', 'Map kept for the field', 'Mapa guardado para el campo'),
  'ai.op.keep_field_map': ('Guardar o mapa da área para o campo', 'Keep the map of the area for the field', 'Guardar el mapa del área para el campo'),
};
