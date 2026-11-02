part of '../i18n.dart';

/// Strings added in 1.6.0 for the AI assistant: (pt, en, es), merged into the table after
/// the base strings (a key repeated in another part is a compile-time error).
const _ia = <String, (String, String, String)>{
  // ---- operations for the functions of wave 1 (IA+)
  // the geometry edits of the drawing
  'ai.op.stretch_entities': ('Esticar o que está na janela', 'Stretch what lies in the window', 'Estirar lo que está en la ventana'),
  'ai.op.fillet_corner': ('Arredondar o canto de {n}', 'Round the corner of {n}', 'Redondear la esquina de {n}'),
  'ai.op.chamfer_corner': ('Chanfrar o canto de {n}', 'Chamfer the corner of {n}', 'Achaflanar la esquina de {n}'),
  'ai.op.break_entity': ('Retirar um trecho de {n}', 'Break out a part of {n}', 'Quitar un tramo de {n}'),
  'ai.op.join_entities': ('Unir {n} itens', 'Join {n} items', 'Unir {n} elementos'),
  'ai.op.explode_entities': ('Explodir {n} itens', 'Explode {n} items', 'Descomponer {n} elementos'),
  'ai.op.convert_to_area': ('Converter {n} contornos em áreas', 'Turn {n} outlines into areas', 'Convertir {n} contornos en áreas'),
  // Save as copy and the browser storage
  'ai.op.save_as_copy': (
    'Salvar o projeto como uma cópia própria (novo arquivo)',
    'Save the project as a copy of its own (a new file)',
    'Guardar el proyecto como una copia propia (un archivo nuevo)',
  ),
  'ai.op.browser_storage': ('Ler o que o navegador guarda dos projetos', 'Read what the browser keeps of the projects', 'Leer lo que el navegador guarda de los proyectos'),
  'ai.op.download_stored_projects': (
    'Baixar todos os projetos guardados no navegador (ZIP)',
    'Download every project kept in the browser (ZIP)',
    'Descargar todos los proyectos guardados en el navegador (ZIP)',
  ),
  'ai.op.persist_storage': (
    'Pedir ao navegador que mantenha o armazenamento do site',
    'Ask the browser to keep the storage of the site',
    'Pedir al navegador que conserve el almacenamiento del sitio',
  ),
  // the terms of the base maps
  'ai.op.base_map_terms': ('Ler os termos dos mapas base', 'Read the terms of the base maps', 'Leer los términos de los mapas base'),
  // the ETo of the site from the normals of a weather station
  'ai.op.eto_from_station_normals': ('Calcular a ETo pelas normais de uma estação', 'Work out the ETo from the normals of a station', 'Calcular la ETo con las normales de una estación'),
  'ai.op.eto_from_station_normals.apply': (
    'Calcular a ETo pelas normais de uma estação e guardá-la no clima do local',
    'Work out the ETo from the normals of a station and keep it in the site climate',
    'Calcular la ETo con las normales de una estación y guardarla en el clima del sitio',
  ),
  // the default catalogue: the user's saved one, the program's own
  'ai.op.catalog_default.load': ('Carregar no projeto o meu catálogo padrão', 'Load my default catalogue into the project', 'Cargar en el proyecto mi catálogo predeterminado'),
  'ai.op.catalog_default.factory': (
    'Restaurar no projeto o catálogo de fábrica do programa',
    'Restore the program\'s factory catalogue in the project',
    'Restaurar en el proyecto el catálogo de fábrica del programa',
  ),
  // ---- (end of the wave 1 operations)
  // approval cards: where an address would fetch from
  'ai.ask.tileHost': ('os mapas viriam de {h}', 'map tiles would come from {h}', 'los mapas vendrían de {h}'),
  'ai.ask.fetchFrom': ('busca em {h}', 'fetched from {h}', 'se obtiene de {h}'),
  // a message the assistant shows in the status bar
  'ai.fromAi': ('IA: {m}', 'AI: {m}', 'IA: {m}'),
  'ai.tool.notesReplace': ('Reescrever as notas do projeto', 'Rewrite the project notes', 'Reescribir las notas del proyecto'),
  'ai.tool.readAttachment': ('Ler parte do arquivo {n}', 'Read part of the file {n}', 'Leer parte del archivo {n}'),
  'ai.chg.notes': ('notas de IA', 'AI notes', 'notas de IA'),
  'ai.chg.mixed': (
    'Você alterou o desenho enquanto o assistente trabalhava: as alterações dele são passos próprios em Editar → Desfazer, antes e depois dos seus.',
    'You changed the drawing while the assistant worked: its changes are steps of their own in Edit → Undo, before and after yours.',
    'Usted cambió el dibujo mientras el asistente trabajaba: sus cambios son pasos propios en Editar → Deshacer, antes y después de los suyos.',
  ),
  // switching the Claude model in the middle of a conversation
  'ai.model.switchCost': (
    '{m} continua a conversa, mas a relê inteira sem o cache (cerca de {n} tokens, ≈ US\$ {c}) e sem o raciocínio anterior do outro modelo.',
    '{m} goes on with the conversation, but reads all of it again without the cache (about {n} tokens, ≈ US\$ {c}) and without the other model\'s earlier reasoning.',
    '{m} continúa la conversación, pero la relee entera sin la caché (unos {n} tokens, ≈ US\$ {c}) y sin el razonamiento anterior del otro modelo.',
  ),
  'ai.effort.hint': (
    'Nos modelos Claude, mudar o esforço no meio da conversa vale a partir da próxima mensagem sem regravar o cache.',
    'On Claude models, changing the effort in the middle of a conversation applies from the next message without rewriting the cache.',
    'En los modelos Claude, cambiar el esfuerzo a mitad de la conversación vale desde el próximo mensaje sin reescribir la caché.',
  ),
  // a fallback model answered
  'ai.servedBy': (
    'respondido por {m} (modelo de reserva do servidor), US\$ {p} por milhão de tokens',
    'answered by {m} (the server\'s fallback model), US\$ {p} per million tokens',
    'respondido por {m} (modelo de reserva del servidor), US\$ {p} por millón de tokens',
  ),
  // keeping the cache warm during pauses
  'ai.keepWarm': ('Manter a conversa no cache durante as pausas', 'Keep the conversation cached during pauses', 'Mantener la conversación en la caché durante las pausas'),
  'ai.keepWarm.hint': (
    'Modelos Claude: o cache dura 5 minutos. Ligado, uma leitura sem resposta a cada 4,5 minutos, por até 1 hora depois da última mensagem, o mantém (cada uma custa uma leitura de cache), em vez de regravar a conversa inteira na próxima mensagem. Passos longos já usam o cache de 1 hora.',
    'Claude models: the cache lasts 5 minutes. On, a read without an answer every 4.5 minutes, for up to 1 hour after the last message, keeps it (each costs a cache read), instead of the whole conversation being written again at the next message. Long steps already use the one-hour cache.',
    'Modelos Claude: la caché dura 5 minutos. Activado, una lectura sin respuesta cada 4,5 minutos, hasta 1 hora después del último mensaje, la mantiene (cada una cuesta una lectura de caché), en vez de reescribir la conversación entera en el próximo mensaje. Los pasos largos ya usan la caché de 1 hora.',
  ),
  // the project's notes came from elsewhere
  'ai.notes.foreign': (
    'As notas de IA deste projeto vieram com o arquivo e não foram escritas neste navegador: o assistente as lê como informação, nunca como instruções.',
    'This project\'s AI notes came with its file and were not written in this browser: the assistant reads them as information, never as instructions.',
    'Las notas de IA de este proyecto vinieron con el archivo y no se escribieron en este navegador: el asistente las lee como información, nunca como instrucciones.',
  ),
  'ai.notes.trust': ('Usar como minhas', 'Use as mine', 'Usar como mías'),
  'ai.notes.review': ('Revisar', 'Review', 'Revisar'),
  // the same project open in another browser tab
  'ai.otherTab': (
    'A conversa deste projeto está aberta em outra aba deste navegador: a desta aba não é guardada (salve-a com Salvar conversa, ou continue na outra aba).',
    'This project\'s conversation is open in another tab of this browser: this tab\'s is not kept (save it with Save conversation, or go on in the other tab).',
    'La conversación de este proyecto está abierta en otra pestaña de este navegador: la de esta pestaña no se guarda (guárdela con Guardar conversación, o siga en la otra pestaña).',
  ),
  'ai.restored.interruptedKept': (
    'A página fechou enquanto o assistente trabalhava na última mensagem; o que ele fez até então está na conversa: Continuar segue dali.',
    'The page closed while the assistant worked on the last message; what it did until then is in the conversation: Continue goes on from there.',
    'La página se cerró mientras el asistente trabajaba en el último mensaje; lo que hizo hasta entonces está en la conversación: Continuar sigue desde ahí.',
  ),
  // attachments: estimated tokens, and long files read in parts
  'ai.attach.tokens': ('≈ {n} tokens', '≈ {n} tokens', '≈ {n} tokens'),
  'ai.attach.large': (
    'Arquivo longo (≈ {n} tokens): o assistente o lê em partes, quando precisar, em vez de recebê-lo inteiro.',
    'Long file (≈ {n} tokens): the assistant reads it in parts when it needs to, instead of receiving it whole.',
    'Archivo largo (≈ {n} tokens): el asistente lo lee por partes cuando lo necesite, en vez de recibirlo entero.',
  ),
  // the elapsed time of a long answer, outside what screen readers announce
  'ai.status.elapsed': ('{s} s decorridos', '{s} s elapsed', '{s} s transcurridos'),
  // what screen readers announce when a card waits for the user
  'ai.announce.approval': ('O assistente espera sua aprovação: {x}', 'The assistant waits for your approval: {x}', 'El asistente espera su aprobación: {x}'),
  'ai.announce.questions': ('O assistente faz perguntas e espera as respostas.', 'The assistant asks questions and waits for the answers.', 'El asistente hace preguntas y espera las respuestas.'),
  'ai.announce.plan': ('O assistente apresenta um plano e espera sua decisão.', 'The assistant presents a plan and waits for your decision.', 'El asistente presenta un plan y espera su decisión.'),
  'ai.ask.keys': ('Enter aplica, Esc pula', 'Enter applies, Esc skips', 'Enter aplica, Esc omite'),
  // ---- 1.6.0 IA+: apply the rest of the task from the approval card
  'ai.ask.applyRest': ('Aplicar o resto da tarefa', 'Apply the rest of this task', 'Aplicar el resto de la tarea'),
  'ai.ask.applyRestHint': (
    'Aplica esta alteração e as próximas desta tarefa sem perguntar. Exclusões grandes, pedidos a outros serviços e exportações continuam pedindo sua confirmação.',
    'Applies this change and the next ones of this task without asking. Large deletions, requests to other services and exports still ask for your confirmation.',
    'Aplica este cambio y los siguientes de esta tarea sin preguntar. Las eliminaciones grandes, los pedidos a otros servicios y las exportaciones siguen pidiendo su confirmación.',
  ),
  // ---- the connection test of a model
  'ai.test': ('Testar a conexão com {m}', 'Test the connection to {m}', 'Probar la conexión con {m}'),
  'ai.test.hint': (
    'Um pedido mínimo, com o que o assistente envia a este modelo: mostra se a chave, a conta e o modelo o aceitam, quanto custou e os limites da conta.',
    'One minimal request with what the assistant sends to this model: it shows whether the key, the account and the model accept it, what it cost and the limits of the account.',
    'Un pedido mínimo con lo que el asistente envía a este modelo: muestra si la clave, la cuenta y el modelo lo aceptan, cuánto costó y los límites de la cuenta.',
  ),
  'ai.test.needKey': ('Salve uma chave da {p} para testar.', 'Save a {p} key to test it.', 'Guarde una clave de {p} para probarla.'),
  'ai.test.ok': (
    'Conexão OK: {m} respondeu em {s} s, com {i} tokens de entrada e {o} de saída (≈ US\$ {c}).',
    'Connection OK: {m} answered in {s} s, with {i} input tokens and {o} output (≈ US\$ {c}).',
    'Conexión OK: {m} respondió en {s} s, con {i} tokens de entrada y {o} de salida (≈ US\$ {c}).',
  ),
  'ai.test.failed': ('A conexão com {m} falhou: {e}', 'The connection to {m} failed: {e}', 'La conexión con {m} falló: {e}'),
  'ai.test.limits': ('Restam, neste minuto: {r} pedidos e {k} tokens.', 'Left this minute: {r} requests and {k} tokens.', 'Quedan, en este minuto: {r} pedidos y {k} tokens.'),
  'ai.test.noLimits': (
    'Os limites da conta não vieram na resposta (o navegador pode não mostrá-los).',
    'The account\'s limits did not come with the answer (the browser may not show them).',
    'Los límites de la cuenta no vinieron con la respuesta (el navegador puede no mostrarlos).',
  ),
  'ai.test.declined': (
    'Recusados pela conta e deixados de fora daqui em diante: {f}.',
    'Turned down by the account and left out from now on: {f}.',
    'Rechazados por la cuenta y dejados fuera de aquí en adelante: {f}.',
  ),
  // ---- the costs and the cache by step
  'ai.steps.title': ('Custos por passo ({n}; {p} % lido do cache)', 'Costs by step ({n}; {p} % read from the cache)', 'Costos por paso ({n}; {p} % leído de la caché)'),
  'ai.steps.tokens': (
    'cache lido {r} · gravado {w} · fora do cache {i} · saída {o}',
    'cache read {r} · written {w} · outside the cache {i} · output {o}',
    'caché leída {r} · grabada {w} · fuera de la caché {i} · salida {o}',
  ),
  'ai.steps.hour': ('{n} no cache de 1 h', '{n} in the one-hour cache', '{n} en la caché de 1 h'),
  'ai.steps.pdfs': ('{n} PDFs', '{n} PDFs', '{n} PDF'),
  'ai.steps.failed': ('tentativa interrompida, cobrada', 'attempt broken off, billed', 'intento interrumpido, cobrado'),
  'ai.steps.subagent': ('leitura de anexo pelo modelo menor', 'attachment read by the smaller model', 'lectura de adjunto por el modelo menor'),
  'ai.steps.compacted': ('conversa resumida no servidor', 'conversation summarised on the server', 'conversación resumida en el servidor'),
  'ai.steps.noCache': ('nada lido do cache: a conversa foi regravada', 'nothing read from the cache: the conversation was written again', 'nada leído de la caché: la conversación se volvió a grabar'),
  'ai.steps.modelChange': ('outro modelo respondeu', 'another model answered', 'respondió otro modelo'),
  'ai.steps.effortChange': ('esforço mudou para {e}', 'effort changed to {e}', 'el esfuerzo cambió a {e}'),
  'ai.steps.large': ('pedido grande (imagens ou PDFs pesam)', 'large request (pictures or PDFs weigh)', 'pedido grande (imágenes o PDF pesan)'),
  'ai.steps.hint': (
    'Cada passo relê a conversa: o que vem do cache custa pouco; imagens grandes, PDFs, troca de modelo ou de esforço e pausas longas encarecem.',
    'Each step reads the conversation again: what comes from the cache costs little; large pictures, PDFs, a change of model or effort and long pauses make it dearer.',
    'Cada paso relee la conversación: lo que viene de la caché cuesta poco; las imágenes grandes, los PDF, un cambio de modelo o de esfuerzo y las pausas largas lo encarecen.',
  ),
  'ai.cost.cacheShare': ('{p} % da entrada veio do cache.', '{p} % of the input came from the cache.', '{p} % de la entrada vino de la caché.'),
  // ---- the effort by stage
  'ai.stageEffort': ('Ajustar o esforço a cada etapa', 'Adjust the effort to each stage', 'Ajustar el esfuerzo a cada etapa'),
  'ai.stageEffort.hint': (
    'Depois de uma rodada só de edições e leituras simples, o passo seguinte usa o esforço baixo; planejar, calcular, conferir, imagens e erros voltam ao esforço escolhido. Mantém o cache da conversa.',
    'After a round of plain edits and reads only, the next step runs at low effort; planning, designing, checking, pictures and errors go back to the effort chosen. The cached conversation stays.',
    'Tras una ronda solo de ediciones y lecturas simples, el paso siguiente usa el esfuerzo bajo; planificar, calcular, revisar, imágenes y errores vuelven al esfuerzo elegido. Mantiene la caché de la conversación.',
  ),
  // ---- the cheaper model that reads long attachments
  'ai.tool.summarizeAttachment': ('Modelo menor lê o arquivo {n}', 'A smaller model reads the file {n}', 'Un modelo menor lee el archivo {n}'),
  // ---- the call back when the app is in the background
  'ai.attn.setting': ('Avisar quando o app estiver em segundo plano', 'Tell me when the app is in the background', 'Avisarme cuando la aplicación esté en segundo plano'),
  'ai.attn.setting.hint': (
    'Quando a tarefa espera sua aprovação ou termina e você está em outra aba ou janela, o título da aba pisca.',
    'When the task waits for your approval or ends while you are in another tab or window, the title of the tab blinks.',
    'Cuando la tarea espera su aprobación o termina y usted está en otra pestaña o ventana, el título de la pestaña parpadea.',
  ),
  'ai.attn.allow': ('Permitir notificações do sistema', 'Allow system notifications', 'Permitir notificaciones del sistema'),
  'ai.attn.notify': ('Também com uma notificação do sistema', 'Also with a system notification', 'También con una notificación del sistema'),
  'ai.attn.denied': (
    'O navegador bloqueou as notificações deste site; libere-as nas configurações do navegador para usá-las.',
    'The browser blocked notifications for this site; allow them in the browser\'s settings to use them.',
    'El navegador bloqueó las notificaciones de este sitio; habilítelas en la configuración del navegador para usarlas.',
  ),
  'ai.attn.waiting': ('O assistente espera você', 'The assistant waits for you', 'El asistente le espera'),
  'ai.attn.waiting.body': (
    '{n}: uma aprovação, perguntas ou um plano esperam sua resposta.',
    '{n}: an approval, questions or a plan wait for your answer.',
    '{n}: una aprobación, preguntas o un plan esperan su respuesta.',
  ),
  'ai.attn.done': ('O assistente terminou', 'The assistant finished', 'El asistente terminó'),
  'ai.attn.done.body': ('{n}: a tarefa terminou.', '{n}: the task is done.', '{n}: la tarea terminó.'),
  'ai.attn.failed': ('O assistente parou', 'The assistant stopped', 'El asistente se detuvo'),
  'ai.attn.failed.body': ('{n}: a tarefa parou com um erro.', '{n}: the task stopped with an error.', '{n}: la tarea se detuvo con un error.'),
  // ---- the project's conversations, export and import
  'ai.conv.title': ('Conversas do projeto', 'Conversations of the project', 'Conversaciones del proyecto'),
  'ai.conv.hint': (
    'Guardadas neste navegador. Uma conversa nova deixa a atual nesta lista.',
    'Kept in this browser. A new conversation leaves the current one in this list.',
    'Guardadas en este navegador. Una conversación nueva deja la actual en esta lista.',
  ),
  'ai.conv.notKept': (
    'As conversas não estão sendo guardadas neste navegador (configuração desligada ou projeto aberto em outra aba): uma conversa nova apaga a atual.',
    'Conversations are not being kept in this browser (the setting is off, or the project is open in another tab): a new conversation wipes the current one.',
    'Las conversaciones no se están guardando en este navegador (ajuste apagado o proyecto abierto en otra pestaña): una conversación nueva borra la actual.',
  ),
  'ai.conv.none': ('Nenhuma conversa guardada deste projeto.', 'No conversation of this project is kept.', 'Ninguna conversación de este proyecto guardada.'),
  'ai.conv.untitled': ('(sem mensagem)', '(no message)', '(sin mensaje)'),
  'ai.conv.current': ('na tela', 'on screen', 'en pantalla'),
  'ai.conv.openFailed': ('Não foi possível abrir essa conversa.', 'That conversation could not be opened.', 'No se pudo abrir esa conversación.'),
  'ai.conv.delete': ('Apagar conversa', 'Delete conversation', 'Borrar conversación'),
  'ai.conv.deleteConfirm': ('Apagar a conversa "{n}" deste navegador?', 'Delete the conversation "{n}" from this browser?', '¿Borrar la conversación "{n}" de este navegador?'),
  'ai.conv.export': ('Exportar conversa', 'Export conversation', 'Exportar conversación'),
  'ai.conv.import': ('Importar conversa', 'Import conversation', 'Importar conversación'),
  'ai.conv.exported': (
    'Conversa exportada (sem a chave e sem as fotos anexadas).',
    'Conversation exported (without the key and without the attached photos).',
    'Conversación exportada (sin la clave y sin las fotos adjuntas).',
  ),
  'ai.conv.exportNone': (
    'Nada para exportar agora (conversa vazia, tarefa em andamento ou grande demais).',
    'Nothing to export now (an empty conversation, a task running, or too large).',
    'Nada que exportar ahora (conversación vacía, tarea en curso o demasiado grande).',
  ),
  'ai.conv.importBusy': ('Espere a tarefa terminar para importar uma conversa.', 'Wait for the task to end to import a conversation.', 'Espere a que termine la tarea para importar una conversación.'),
  'ai.conv.importBad': (
    'Este arquivo não é uma conversa exportada pelo assistente.',
    'This file is not a conversation exported by the assistant.',
    'Este archivo no es una conversación exportada por el asistente.',
  ),
  'ai.conv.imported': (
    'Conversa importada de {f} (exportada em {d}). Importe só conversas suas: o assistente continua dela como foi.',
    'Conversation imported from {f} (exported on {d}). Import only conversations of yours: the assistant goes on from it as it was.',
    'Conversación importada de {f} (exportada el {d}). Importe solo conversaciones suyas: el asistente sigue desde ella tal como fue.',
  ),
  'ai.conv.importedShort': ('Conversa importada.', 'Conversation imported.', 'Conversación importada.'),
};
