part of '../i18n.dart';

/// Strings added in 1.7.0 for the AI providers (Google, xAI, Meta and OpenRouter beside Anthropic and OpenAI, the choice of the company and what the settings say about a model): (pt, en, es), merged into the table after
/// the base strings (a key repeated in another part is a compile-time error).
const _aip = <String, (String, String, String)>{
  'ai.provider': ('Empresa', 'Company', 'Empresa'),
  'ai.provider.hasKey': ('{p}: chave salva', '{p}: key saved', '{p}: clave guardada'),
  'ai.key.explain.google': (
    'Os modelos Gemini usam sua própria chave da API Gemini, do Google: o Google cobra o uso na sua conta. Os modelos Flash têm um nível gratuito com limites, no qual o Google pode usar o conteúdo para melhorar seus produtos. Crie uma chave no Google AI Studio.',
    'The Gemini models run on your own Gemini API key, from Google: Google bills the usage to your account. The Flash models have a free tier with limits, on which Google may use the content to improve its products. Create a key in Google AI Studio.',
    'Los modelos Gemini usan su propia clave de la API de Gemini, de Google: Google le factura el uso en su cuenta. Los modelos Flash tienen un nivel gratuito con límites, en el que Google puede usar el contenido para mejorar sus productos. Cree una clave en Google AI Studio.',
  ),
  'ai.key.explain.xai': (
    'Os modelos Grok usam sua própria conta da xAI: a xAI cobra o uso dessa conta. Crie uma chave no console da xAI.',
    'The Grok models run on your own xAI account: xAI bills the usage to it. Create a key in the xAI console.',
    'Los modelos Grok usan su propia cuenta de xAI: xAI le factura el uso. Cree una clave en la consola de xAI.',
  ),
  'ai.key.explain.meta': (
    'Os modelos Muse usam sua própria conta da Meta Model API: a Meta cobra o uso dessa conta. Crie uma chave no portal de desenvolvedores da Meta.',
    'The Muse models run on your own Meta Model API account: Meta bills the usage to it. Create a key in the Meta developer portal.',
    'Los modelos Muse usan su propia cuenta de la Meta Model API: Meta le factura el uso. Cree una clave en el portal de desarrolladores de Meta.',
  ),
  'ai.key.explain.openrouter': (
    'Uma só chave da OpenRouter alcança modelos de muitas empresas (Claude, GPT, Gemini, Grok, Muse e centenas de outros, alguns gratuitos): a OpenRouter cobra o uso dos seus créditos e repassa cada pedido à empresa que opera o modelo. Crie uma chave no site da OpenRouter.',
    'One OpenRouter key reaches the models of many companies (Claude, GPT, Gemini, Grok, Muse and hundreds of others, some of them free): OpenRouter bills the usage to your credits and passes each request on to the company that runs the model. Create a key on the OpenRouter site.',
    'Una sola clave de OpenRouter llega a modelos de muchas empresas (Claude, GPT, Gemini, Grok, Muse y cientos más, algunos gratuitos): OpenRouter cobra el uso de sus créditos y pasa cada solicitud a la empresa que opera el modelo. Cree una clave en el sitio de OpenRouter.',
  ),
  'ai.model.freeTier': ('nível gratuito', 'free tier', 'nivel gratuito'),
  'ai.model.freeHint': (
    'Este modelo tem um nível gratuito, com limites da própria empresa; nele, ela pode usar o que é enviado para melhorar seus produtos (veja os termos dela). Os preços acima são os do uso pago.',
    'This model has a free tier, with limits set by its company; on it, the company may use what is sent to improve its products (see its terms). The prices above are those of paid use.',
    'Este modelo tiene un nivel gratuito, con límites de la propia empresa; en él, la empresa puede usar lo que se envía para mejorar sus productos (vea sus términos). Los precios de arriba son los del uso de pago.',
  ),
  'ai.model.intro': (
    'Preço de lançamento até {d}; depois, US\$ {i} de entrada e US\$ {o} de saída.',
    'Introductory price until {d}; afterwards US\$ {i} input and US\$ {o} output.',
    'Precio de lanzamiento hasta el {d}; después, US\$ {i} de entrada y US\$ {o} de salida.',
  ),
  'ai.model.router': (
    'É um roteador: a OpenRouter escolhe o modelo a cada pedido e cobra o preço dele; o medidor mostra o custo quando conhece o modelo que respondeu.',
    'This is a router: OpenRouter picks the model for each request and bills that model\'s price; the meter shows the cost when it knows the model that answered.',
    'Es un enrutador: OpenRouter elige el modelo en cada solicitud y cobra su precio; el medidor muestra el costo cuando conoce el modelo que respondió.',
  ),
  'ai.model.via': (
    'A OpenRouter repassa o pedido à empresa que opera o modelo, nos termos da sua conta na OpenRouter.',
    'OpenRouter passes the request on to the company that runs the model, under the terms of your OpenRouter account.',
    'OpenRouter pasa la solicitud a la empresa que opera el modelo, según los términos de su cuenta de OpenRouter.',
  ),
  'ai.model.noVision': (
    'Este modelo não lê imagens: o assistente trabalha sem ver o desenho nem o mapa.',
    'This model does not read pictures: the assistant works without seeing the drawing or the map.',
    'Este modelo no lee imágenes: el asistente trabaja sin ver el dibujo ni el mapa.',
  ),
  'ai.model.browse': ('Mais modelos…', 'More models…', 'Más modelos…'),
  'ai.model.browse.hint': (
    'Abre a lista completa da OpenRouter (centenas de modelos, alguns gratuitos) para escolher outro.',
    'Opens OpenRouter\'s whole list (hundreds of models, some of them free) to choose another one.',
    'Abre la lista completa de OpenRouter (cientos de modelos, algunos gratuitos) para elegir otro.',
  ),
  'ai.model.noTools': (
    'Este modelo não usa ferramentas: ele só conversa, com os dados do projeto anexados; não lê mais do projeto nem o altera.',
    'This model does not call tools: it only talks, with the project data attached; it reads nothing else of the project and changes nothing.',
    'Este modelo no usa herramientas: solo conversa, con los datos del proyecto adjuntos; no lee nada más del proyecto ni lo modifica.',
  ),
  'ai.attach.noVision': (
    'O {m} não lê imagens: as imagens anexadas não foram enviadas.',
    '{m} does not read pictures: the pictures attached were not sent.',
    '{m} no lee imágenes: las imágenes adjuntas no se enviaron.',
  ),
  'ai.err.cat.recitation': ('repetição de texto protegido', 'repetition of protected text', 'repetición de texto protegido'),
  'ai.err.cat.language': ('idioma não atendido pelo modelo', 'a language the model does not serve', 'idioma que el modelo no atiende'),
  // ---- a second opinion: another model checks the last answer
  'ai.cmd.second': (
    'pede a outro modelo uma segunda opinião sobre a última resposta',
    'asks another model for a second opinion on the last answer',
    'pide a otro modelo una segunda opinión sobre la última respuesta',
  ),
  'ai.second': ('Segunda opinião', 'Second opinion', 'Segunda opinión'),
  'ai.second.by': ('Segunda opinião de {m}', 'Second opinion from {m}', 'Segunda opinión de {m}'),
  'ai.second.none': ('Ainda não há uma resposta para revisar.', 'There is no answer to review yet.', 'Aún no hay una respuesta que revisar.'),
  'ai.second.status': ('{m} está revisando a resposta…', '{m} is reviewing the answer…', '{m} está revisando la respuesta…'),
  'ai.second.sends': (
    'Outro modelo confere a resposta: a pergunta, a resposta e os dados do projeto vão para a empresa dele.',
    'Another model checks the answer: the question, the answer and the project data go to its company.',
    'Otro modelo comprueba la respuesta: la pregunta, la respuesta y los datos del proyecto van a su empresa.',
  ),
  'ai.second.forward': ('Responder à revisão', 'Answer the review', 'Responder a la revisión'),
  'ai.second.forward.prompt': (
    'Outro modelo ({m}) revisou a sua última resposta. Confira cada ponto no projeto, com as ferramentas, diga quais procedem e corrija o que for preciso.',
    'Another model ({m}) reviewed your last answer. Check each point against the project, with the tools, say which ones hold and correct what needs correcting.',
    'Otro modelo ({m}) revisó su última respuesta. Compruebe cada punto en el proyecto, con las herramientas, diga cuáles proceden y corrija lo que haga falta.',
  ),
};
