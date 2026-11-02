part of '../i18n.dart';

/// Strings added in 1.6.0 for drawing board, editing and local storage: (pt, en, es), merged into the table after
/// the base strings (a key repeated in another part is a compile-time error).
const _cad = <String, (String, String, String)>{
  // ---- copies in the browser (autosave, versions, recovery)
  'store.problem': ('Não guardado no navegador', 'Not kept in the browser', 'No guardado en el navegador'),
  'store.err.full': (
    'O armazenamento do navegador está cheio: a cópia deste projeto não pôde ser guardada. Salve o arquivo do projeto (Ctrl+S) para não perder o trabalho.',
    'The browser storage is full: the copy of this project could not be kept. Save the project file (Ctrl+S) so the work is not lost.',
    'El almacenamiento del navegador está lleno: no se pudo guardar la copia de este proyecto. Guarde el archivo del proyecto (Ctrl+S) para no perder el trabajo.',
  ),
  'store.err.unavailable': (
    'Este navegador não deixa o app guardar cópias (armazenamento bloqueado ou janela privada). Salve o arquivo do projeto (Ctrl+S) para não perder o trabalho.',
    'This browser does not let the app keep copies (storage blocked or a private window). Save the project file (Ctrl+S) so the work is not lost.',
    'Este navegador no deja que la app guarde copias (almacenamiento bloqueado o ventana privada). Guarde el archivo del proyecto (Ctrl+S) para no perder el trabajo.',
  ),
  'store.err.tooLarge': (
    'O projeto é grande demais para a cópia no navegador, mesmo comprimido e sem as imagens. Salve o arquivo do projeto (Ctrl+S) com frequência.',
    'The project is too large for the copy in the browser, even compressed and without its pictures. Save the project file (Ctrl+S) often.',
    'El proyecto es demasiado grande para la copia en el navegador, incluso comprimido y sin las imágenes. Guarde el archivo del proyecto (Ctrl+S) con frecuencia.',
  ),
  'store.err.version': (
    'A cópia foi guardada, mas não coube uma nova versão no histórico do navegador.',
    'The copy was kept, but a new version did not fit in the browser history.',
    'La copia se guardó, pero no cupo una nueva versión en el historial del navegador.',
  ),
  'store.err.read': ('A cópia guardada no navegador não pôde ser lida.', 'The copy kept in the browser could not be read.', 'No se pudo leer la copia guardada en el navegador.'),
  'store.notBackup': (
    'Estas cópias ficam só neste navegador, neste aparelho: não são um backup. Limpar os dados do site (ou, no Safari, ficar 7 dias sem abrir o app) as apaga. O arquivo .oci.json salvo é o que guarda o projeto.',
    'These copies stay in this browser, on this device only: they are not a backup. Clearing the site data (or, in Safari, 7 days without opening the app) erases them. The saved .oci.json file is what keeps the project.',
    'Estas copias quedan solo en este navegador, en este dispositivo: no son una copia de seguridad. Borrar los datos del sitio (o, en Safari, 7 días sin abrir la app) las elimina. El archivo .oci.json guardado es lo que conserva el proyecto.',
  ),
  'store.advice': (
    'Seu trabalho é copiado automaticamente só neste navegador: salve o arquivo do projeto (Ctrl+S) para guardá-lo de verdade.',
    'Your work is copied automatically in this browser only: save the project file (Ctrl+S) to really keep it.',
    'Su trabajo se copia automáticamente solo en este navegador: guarde el archivo del proyecto (Ctrl+S) para conservarlo de verdad.',
  ),
  'store.adviceSafari': (
    'Seu trabalho é copiado só neste navegador, e o Safari apaga essas cópias depois de 7 dias sem abrir o app: salve o arquivo do projeto (Ctrl+S).',
    'Your work is copied in this browser only, and Safari erases these copies after 7 days without opening the app: save the project file (Ctrl+S).',
    'Su trabajo se copia solo en este navegador, y Safari borra esas copias tras 7 días sin abrir la app: guarde el archivo del proyecto (Ctrl+S).',
  ),
  'rec.text2': (
    'Estes projetos têm alterações copiadas automaticamente neste navegador que não foram salvas em arquivo (o app ou o navegador fechou antes). Marque o que deseja recuperar ou descartar.',
    'These projects have changes copied automatically in this browser that were not saved to a file (the app or the browser closed first). Tick what to recover or to discard.',
    'Estos proyectos tienen cambios copiados automáticamente en este navegador que no se guardaron en un archivo (la app o el navegador se cerró antes). Marque lo que desea recuperar o descartar.',
  ),
  'rec.hasVersions': ('{n} versão(ões) salva(s) ficam no histórico', '{n} saved version(s) stay in the history', '{n} versión(es) guardada(s) quedan en el historial'),
  'rec.discardNote': (
    'Descartar apaga só as alterações não salvas: o projeto volta à última versão salva, e o histórico de versões continua.',
    'Discarding drops only the unsaved changes: the project goes back to its last saved version, and the version history stays.',
    'Descartar elimina solo los cambios no guardados: el proyecto vuelve a su última versión guardada, y el historial de versiones se mantiene.',
  ),
  'ver.restoreConfirm': (
    'O projeto tem alterações não salvas. Restaurar a versão {v}? Ctrl+Z traz o trabalho de volta como está agora.',
    'The project has unsaved changes. Restore version {v}? Ctrl+Z brings the work back as it is now.',
    'El proyecto tiene cambios sin guardar. ¿Restaurar la versión {v}? Ctrl+Z devuelve el trabajo tal como está ahora.',
  ),
  'msg.versionRestoredUndo': ('Versão {v} restaurada (Ctrl+Z desfaz)', 'Version {v} restored (Ctrl+Z undoes it)', 'Versión {v} restaurada (Ctrl+Z la deshace)'),
  'hist.versionRestore': ('Restaurar versão {n}', 'Restore version {n}', 'Restaurar versión {n}'),
  // ---- two tabs or windows, copies with a uid of their own
  'msg.openedAsCopyTab': (
    'Este projeto já está aberto em outra aba: esta aba é uma cópia, com cópia automática e versões próprias.',
    'This project is open in another tab already: this tab is a copy, with its own autosave and versions.',
    'Este proyecto ya está abierto en otra pestaña: esta pestaña es una copia, con copia automática y versiones propias.',
  ),
  'msg.openedAsCopyKept': (
    'Este navegador guarda alterações não salvas deste projeto (Arquivo → Projetos recentes): o arquivo abriu como uma cópia, para não as sobrescrever.',
    'This browser keeps unsaved changes of this project (File → Recent projects): the file opened as a copy, so they are not overwritten.',
    'Este navegador guarda cambios sin guardar de este proyecto (Archivo → Proyectos recientes): el archivo se abrió como una copia, para no sobrescribirlos.',
  ),
  'msg.openedAsCopyWindow': (
    'Este projeto está aberto em outra janela do navegador: esta aba passou a ser uma cópia, para que uma não sobrescreva a cópia automática da outra.',
    'This project is open in another browser window: this tab became a copy, so neither overwrites the other\'s autosave.',
    'Este proyecto está abierto en otra ventana del navegador: esta pestaña pasó a ser una copia, para que ninguna sobrescriba la copia automática de la otra.',
  ),
  'msg.exampleReplaces': (
    'O exemplo vai substituir o projeto desta aba. Continuar? (Ctrl+Z não traz o projeto de volta; a cópia automática sim.)',
    'The example will replace the project of this tab. Continue? (Ctrl+Z does not bring the project back; its copy in the browser does.)',
    'El ejemplo reemplazará el proyecto de esta pestaña. ¿Continuar? (Ctrl+Z no devuelve el proyecto; su copia en el navegador sí.)',
  ),
  // ---- saving files
  'file.saveAs': ('Salvar como…', 'Save as…', 'Guardar como…'),
  'file.saveCopy': ('Salvar como cópia…', 'Save as copy…', 'Guardar como copia…'),
  'file.copyName': ('{n} (cópia)', '{n} (copy)', '{n} (copia)'),
  'msg.saveCancelled': ('Não salvo: a janela de salvar foi fechada.', 'Not saved: the save dialog was closed.', 'No guardado: se cerró la ventana de guardar.'),
  'msg.saveFailed': ('O arquivo não pôde ser gravado.', 'The file could not be written.', 'No se pudo escribir el archivo.'),
  'msg.savedDownload': (
    'Download de {f} iniciado: confira se o navegador o salvou na pasta de downloads. Uma versão fica também no histórico do navegador.',
    'Download of {f} started: check that the browser saved it in the downloads folder. A version also stays in the browser history.',
    'Descarga de {f} iniciada: compruebe que el navegador la guardó en la carpeta de descargas. Una versión queda también en el historial del navegador.',
  ),
  // ---- browser storage dialog
  'file.storage': ('Armazenamento do navegador…', 'Browser storage…', 'Almacenamiento del navegador…'),
  'storage.title': ('Armazenamento do navegador', 'Browser storage', 'Almacenamiento del navegador'),
  'storage.where': ('Onde: {w}', 'Where: {w}', 'Dónde: {w}'),
  'storage.whereDb': ('banco de dados do navegador (IndexedDB)', 'the browser database (IndexedDB)', 'base de datos del navegador (IndexedDB)'),
  'storage.whereLocal': ('localStorage (cerca de 5 MB para o site todo)', 'localStorage (about 5 MB for the whole site)', 'localStorage (unos 5 MB para todo el sitio)'),
  'storage.whereMemory': ('memória (perde-se ao fechar o app)', 'memory (lost when the app closes)', 'memoria (se pierde al cerrar la app)'),
  'storage.used': ('Usado pelo site: {u} MB de {q} MB disponíveis', 'Used by the site: {u} MB of {q} MB available', 'Usado por el sitio: {u} MB de {q} MB disponibles'),
  'storage.persistYes': (
    'O navegador mantém estes dados mesmo com pouco espaço.',
    'The browser keeps this data even when space runs short.',
    'El navegador conserva estos datos aunque falte espacio.',
  ),
  'storage.persistNo': (
    'O navegador pode apagar estes dados quando faltar espaço.',
    'The browser may erase this data when space runs short.',
    'El navegador puede borrar estos datos cuando falte espacio.',
  ),
  'storage.persistUnknown': ('O navegador não informa se mantém estes dados.', 'The browser does not say whether it keeps this data.', 'El navegador no informa si conserva estos datos.'),
  'storage.persistAsk': ('Pedir para manter', 'Ask to keep it', 'Pedir que los conserve'),
  'storage.kept': ('Projetos guardados aqui: {n}', 'Projects kept here: {n}', 'Proyectos guardados aquí: {n}'),
  'storage.kindAutosave': ('alterações não salvas', 'unsaved changes', 'cambios sin guardar'),
  'storage.kindSaved': ('salvo', 'saved', 'guardado'),
  'storage.versions': ('{n} versões', '{n} versions', '{n} versiones'),
  'storage.thisTab': ('esta aba', 'this tab', 'esta pestaña'),
  'storage.zip': ('Baixar todos (ZIP)', 'Download all (ZIP)', 'Descargar todos (ZIP)'),
  'storage.zipped': ('{n} projeto(s) baixado(s) num ZIP', '{n} project(s) downloaded in a ZIP', '{n} proyecto(s) descargado(s) en un ZIP'),
  'storage.safari': (
    'No Safari, sem o app instalado na tela inicial, o navegador apaga estes dados depois de 7 dias sem uso do site: salve os arquivos dos projetos.',
    'In Safari, unless the app is installed on the home screen, the browser erases this data after 7 days without using the site: save the project files.',
    'En Safari, sin la app instalada en la pantalla de inicio, el navegador borra estos datos tras 7 días sin usar el sitio: guarde los archivos de los proyectos.',
  ),
  // ---- unexpected errors
  'err.unexpected': (
    'Algo deu errado. Seu trabalho foi copiado no navegador; se algo parecer estranho, salve o projeto e recarregue a página.',
    'Something went wrong. Your work was copied in the browser; if anything looks wrong, save the project and reload the page.',
    'Algo salió mal. Su trabajo se copió en el navegador; si algo parece extraño, guarde el proyecto y recargue la página.',
  ),
  'err.part': (
    'Esta parte da janela não pôde ser desenhada. Seu trabalho está copiado no navegador.',
    'This part of the window could not be drawn. Your work is copied in the browser.',
    'Esta parte de la ventana no se pudo dibujar. Su trabajo está copiado en el navegador.',
  ),
  // ---- the design
  'design.cancel': ('Cancelar o cálculo', 'Cancel the design', 'Cancelar el cálculo'),
  'msg.designCancelled': ('Cálculo cancelado: o projeto ficou como estava.', 'Design cancelled: the project stays as it was.', 'Cálculo cancelado: el proyecto quedó como estaba.'),
  // ---- GPS walk
  'gps.walkDiscard': ('Descartar a caminhada', 'Discard the walk', 'Descartar la caminata'),
  'gps.walkDiscarded': ('Caminhada descartada', 'Walk discarded', 'Caminata descartada'),
  'gps.walkResumed': ('Caminhada retomada com {n} pontos', 'Walk resumed with {n} points', 'Caminata retomada con {n} puntos'),
  'gps.keepScreenOn': (
    'Mantenha a tela ligada durante a caminhada: com a tela apagada o navegador para de dar posições.',
    'Keep the screen on during the walk: with the screen off the browser stops giving positions.',
    'Mantenga la pantalla encendida durante la caminata: con la pantalla apagada el navegador deja de dar posiciones.',
  ),
  // ---- georeference
  'hist.georef': ('Georreferência', 'Georeference', 'Georreferencia'),
  'hist.georefRemove': ('Remover georreferência', 'Remove georeference', 'Quitar georreferencia'),
  'geo.removeConfirm': (
    'Remover a georreferência? O mapa base, o MDT on-line e as exportações geográficas deixam de funcionar até ela ser definida de novo. Ctrl+Z a traz de volta.',
    'Remove the georeference? The base map, the online DEM and the geographic exports stop working until it is set again. Ctrl+Z brings it back.',
    '¿Quitar la georreferencia? El mapa base, el MDT en línea y las exportaciones geográficas dejan de funcionar hasta que se defina de nuevo. Ctrl+Z la devuelve.',
  ),
  'msg.pastedOnMap': (
    '(no mesmo lugar do mapa: os dois projetos têm origens diferentes)',
    '(at the same place on the map: the two projects have different origins)',
    '(en el mismo lugar del mapa: los dos proyectos tienen orígenes diferentes)',
  ),
  // ---- base maps
  'basemap.httpBlocked': (
    'Endereço http:// bloqueado: o navegador não carrega blocos sem HTTPS numa página HTTPS (só http://localhost funciona). Use o endereço https:// do servidor.',
    'http:// address blocked: the browser loads no tiles without HTTPS on an HTTPS page (only http://localhost works). Use the server\'s https:// address.',
    'Dirección http:// bloqueada: el navegador no carga teselas sin HTTPS en una página HTTPS (solo http://localhost funciona). Use la dirección https:// del servidor.',
  ),
  'basemap.googleKey.remember': ('Lembrar a chave neste navegador', 'Remember the key in this browser', 'Recordar la clave en este navegador'),
  'basemap.googleKey.rememberHint': (
    'Desmarcado, a chave vale só enquanto a página estiver aberta. O que o navegador guarda pode ser lido por qualquer script do site.',
    'Unticked, the key lasts only while the page is open. What the browser keeps can be read by any script of the site.',
    'Sin marcar, la clave vale solo mientras la página esté abierta. Lo que el navegador guarda puede leerlo cualquier script del sitio.',
  ),
  'basemap.osm.menu': ('Servidor do mapa de ruas…', 'Street map server…', 'Servidor del mapa de calles…'),
  'basemap.osm.title': ('Servidor do mapa de ruas', 'Street map server', 'Servidor del mapa de calles'),
  'basemap.osm.explain': (
    'O mapa de ruas usa blocos do OpenStreetMap. O servidor da Fundação OpenStreetMap é mantido por voluntários e sua política pede que não seja usado de forma intensa por aplicativos: quem usa muito o mapa (ou uma empresa) deve usar outro servidor dos mesmos blocos, próprio ou contratado. Deixe em branco para usar o da Fundação.',
    'The street map uses OpenStreetMap tiles. The OpenStreetMap Foundation\'s server is run by volunteers, and its policy asks apps not to use it heavily: heavy users (or a company) should use another server of the same tiles, their own or a paid one. Leave it empty to use the Foundation\'s.',
    'El mapa de calles usa teselas de OpenStreetMap. El servidor de la Fundación OpenStreetMap lo mantienen voluntarios y su política pide que las aplicaciones no lo usen de forma intensa: quien use mucho el mapa (o una empresa) debe usar otro servidor de las mismas teselas, propio o contratado. Déjelo en blanco para usar el de la Fundación.',
  ),
  'basemap.osm.policy': ('Política de uso dos blocos', 'Tile usage policy', 'Política de uso de las teselas'),
  'basemap.osm.field': ('Modelo XYZ do servidor ({z}, {x}, {y})', 'XYZ template of the server ({z}, {x}, {y})', 'Plantilla XYZ del servidor ({z}, {x}, {y})'),
  'basemap.osm.default': ('Usar o da Fundação', 'Use the Foundation\'s', 'Usar el de la Fundación'),
  'basemap.terms.menu': ('Termos dos mapas…', 'Terms of the maps…', 'Términos de los mapas…'),
  'basemap.terms.title': ('Termos dos mapas base', 'Terms of the base maps', 'Términos de los mapas base'),
  'basemap.terms.intro': (
    'Os mapas base vêm de serviços de terceiros, cada um com seus termos. O crédito de cada um aparece sobre o mapa (com link) e nas pranchas exportadas.',
    'The base maps come from third-party services, each with its own terms. The credit of each one is shown over the map (with a link) and on the exported sheets.',
    'Los mapas base vienen de servicios de terceros, cada uno con sus términos. El crédito de cada uno aparece sobre el mapa (con enlace) y en las láminas exportadas.',
  ),
  'basemap.terms.osm': (
    'Dados © colaboradores do OpenStreetMap (ODbL). O servidor da Fundação é mantido por voluntários: a política pede o crédito e nada de uso intenso; as pranchas exportadas baixam menos blocos dele. Para uso intenso, configure outro servidor (Servidor do mapa de ruas…).',
    'Data © OpenStreetMap contributors (ODbL). The Foundation\'s server is run by volunteers: its policy asks for the credit and no heavy use; exported sheets take fewer of its tiles. For heavy use, set another server (Street map server…).',
    'Datos © colaboradores de OpenStreetMap (ODbL). El servidor de la Fundación lo mantienen voluntarios: la política pide el crédito y nada de uso intensivo; las láminas exportadas descargan menos teselas de él. Para uso intensivo, configure otro servidor (Servidor del mapa de calles…).',
  ),
  'basemap.terms.topo': (
    'Dados © colaboradores do OpenStreetMap, SRTM; estilo © OpenTopoMap (CC-BY-SA). Servidor gratuito de capacidade limitada: evite uso intenso.',
    'Data © OpenStreetMap contributors, SRTM; style © OpenTopoMap (CC-BY-SA). A free server of limited capacity: avoid heavy use.',
    'Datos © colaboradores de OpenStreetMap, SRTM; estilo © OpenTopoMap (CC-BY-SA). Servidor gratuito de capacidad limitada: evite el uso intensivo.',
  ),
  'basemap.terms.carto': (
    'Dados © colaboradores do OpenStreetMap, estilo © CARTO. Os mapas base da CARTO são gratuitos para uso não comercial; o uso comercial pede uma licença da CARTO.',
    'Data © OpenStreetMap contributors, style © CARTO. The CARTO base maps are free for non-commercial use; commercial use needs a CARTO licence.',
    'Datos © colaboradores de OpenStreetMap, estilo © CARTO. Los mapas base de CARTO son gratuitos para uso no comercial; el uso comercial requiere una licencia de CARTO.',
  ),
  'basemap.terms.esri': (
    'Imagens e mapas da Esri e de seus parceiros, com o crédito mostrado. O uso segue os termos da Esri: confira-os para uso comercial.',
    'Imagery and maps of Esri and its partners, with the credit shown. Their use follows the Esri terms: check them for commercial use.',
    'Imágenes y mapas de Esri y sus socios, con el crédito mostrado. Su uso sigue los términos de Esri: revíselos para uso comercial.',
  ),
  'basemap.terms.google': (
    'Map Tiles API com a sua própria chave (cobrada no seu projeto do Google Cloud). Os termos pedem o logotipo do Google e o crédito dos dados junto dos blocos 2D: o crédito aparece aqui; inclua o logotipo onde publicar o mapa.',
    'Map Tiles API with your own key (billed to your Google Cloud project). The terms ask for the Google logo and the data credit next to the 2D tiles: the credit is shown here; add the logo wherever you publish the map.',
    'Map Tiles API con su propia clave (facturada en su proyecto de Google Cloud). Los términos piden el logotipo de Google y el crédito de los datos junto a las teselas 2D: el crédito aparece aquí; incluya el logotipo donde publique el mapa.',
  ),
  // ---- history labels
  'hist.offset': ('Offset', 'Offset', 'Desfase'),
  'hist.trim': ('Aparar', 'Trim', 'Recortar'),
  'hist.extend': ('Estender', 'Extend', 'Alargar'),
  'hist.cut': ('Cortar', 'Cut', 'Cortar'),
  'hist.grip': ('Mover alça', 'Move grip', 'Mover pinzamiento'),
  'hist.vertexAdd': ('Inserir vértice', 'Insert vertex', 'Insertar vértice'),
  'hist.vertexRemove': ('Remover vértice', 'Remove vertex', 'Quitar vértice'),
  'hist.layerColor': ('Cor da camada', 'Layer colour', 'Color de la capa'),
  'hist.layerAdd': ('Nova camada', 'New layer', 'Nueva capa'),
  'hist.layerRename': ('Renomear camada', 'Rename layer', 'Renombrar capa'),
  'hist.layerRemove': ('Remover camada', 'Remove layer', 'Quitar capa'),
};
