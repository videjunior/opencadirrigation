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
