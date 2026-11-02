part of '../i18n.dart';

/// Strings added in 1.6.0 for the AI assistant: (pt, en, es), merged into the table after
/// the base strings (a key repeated in another part is a compile-time error).
const _ia = <String, (String, String, String)>{
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
};
