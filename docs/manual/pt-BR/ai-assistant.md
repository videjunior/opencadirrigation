# Assistente de IA

Projeto → Assistente de IA… (`IA`, `AI`, `ASK`), o botão dele na barra de status ou **Perguntar à
IA** em qualquer cartão de mensagem abre um agente de IA que trabalha no projeto aberto num painel
encaixado ao lado do desenho (uma folha inferior no celular), para você ver o desenho mudar enquanto
ele trabalha. Ele usa um modelo de uma de seis empresas, com a sua própria chave de API dessa
empresa: Anthropic (Claude, pela API Messages), OpenAI (GPT, pela API Responses), Google (Gemini,
pela Interactions API), xAI (Grok, pela Responses API dela), Meta (Muse, pela Meta Model API no
formato Responses) ou OpenRouter (uma só chave para os modelos de muitas empresas, pela Responses
API dela). O navegador (ou o app de desktop) chama a API da empresa diretamente, sem servidor deste
projeto no meio, e a empresa cobra o uso na sua conta. O painel mostra os tokens de cada resposta e
da conversa, com uma estimativa em US$ pelos preços de tabela abaixo, que podem mudar.

## Empresas e modelos

Os modelos oferecidos, com os preços de tabela por milhão de tokens como cada empresa os publicava
em 2026-11-10 (`lib/core/ai/llm.dart` guarda a tabela que o app usa):

| Empresa | Nível | Modelo | Id | US$ por milhão de tokens, entrada / saída | Para saber |
|---|---|---|---|---|---|
| Anthropic | topo | Claude Fable 5.2 | `claude-fable-5-2` | 8 / 40 | exige retenção de dados de 30 dias; pode pensar minutos |
| Anthropic | topo | Claude Opus 5.5 (o padrão) | `claude-opus-5-5` | 4 / 20 | |
| Anthropic | intermediário | Claude Sonnet 5.5 | `claude-sonnet-5-5` | 2 / 10 | |
| Anthropic | rápido | Claude Haiku 5.5 | `claude-haiku-5-5` | 0,10 / 0,50 | 5 × acima de 100 000 tokens de entrada |
| OpenAI | topo | GPT-6 Astra | `gpt-6-astra` | 10 / 50 | pode pensar minutos |
| OpenAI | intermediário | GPT-6.1 Sol | `gpt-6.1-sol` | 2 / 10 | |
| OpenAI | rápido | GPT-6.1 Terra | `gpt-6.1-terra` | 1 / 5 | |
| OpenAI | rápido | GPT-6 Luna | `gpt-6-luna` | 0,10 / 0,50 | |
| OpenAI | intermediário, versões anteriores | GPT-6 Sol, GPT-5.6 Terra | `gpt-6-sol`, `gpt-5.6-terra` | 2 / 10, 2 / 12 | |
| Google | topo | Gemini 4 Argon | `gemini-4-argon` | 4 / 20 | metade do preço até 1º de dezembro de 2026; pode pensar minutos |
| Google | intermediário | Gemini 3.8 Flash | `gemini-3.8-flash` | 1,50 / 7,50 | metade do preço até 1º de janeiro de 2027; nível gratuito |
| Google | rápido | Gemini 3.5 Flash-Lite | `gemini-3.5-flash-lite` | 0,30 / 2,50 | nível gratuito |
| xAI | topo | Grok 4.7 | `grok-4.7` | 2 / 6 | 2 × a partir de 200 000 tokens de prompt |
| xAI | rápido | Grok 4.3 | `grok-4.3` | 1,25 / 2,50 | 2 × a partir de 200 000 tokens de prompt |
| Meta | topo | Muse Wonder | `muse-wonder-1.0` | 4 / 20 | pode pensar minutos |
| Meta | intermediário | Muse Spark 1.3 | `muse-spark-1.3` | 1,25 / 4,25 | |
| Meta | rápido | Muse Ember | `muse-ember-1.0` | 0,10 / 0,50 | 3 × acima de 200 000 tokens de entrada |
| OpenRouter | | Claude Fable 5.2, Opus 5.5, Sonnet 5.5 e Haiku 5.5; GPT-6 Astra, GPT-6.1 Sol e GPT-6.1 Terra; Gemini 4 Argon e Gemini 3.8 Flash; Grok 4.7; Muse Spark 1.3 | `anthropic/claude-opus-5.5`, `openai/gpt-6.1-sol`… | os preços das empresas como a OpenRouter os lista (Gemini 3.8 Flash 1,65 / 8,25) | limite de resposta menor nos mais caros |
| OpenRouter | | Auto Router, Free Models Router | `openrouter/auto`, `openrouter/free` | o preço do modelo que ele escolhe; grátis | roteadores |

As regras de prompt longo valem para o pedido inteiro quando a entrada passa do limite: os modelos
da OpenAI (também pela OpenRouter) acima de 272 000 tokens de entrada custam 2 × na entrada e no
cache e 1,5 × na saída; o Claude Haiku 5.5 acima de 100 000 custa 5 × em tudo; o Grok a partir de
200 000 tokens de prompt custa 2 × em tudo; o Muse Ember acima de 200 000 tokens de entrada
(contando os em cache) custa 3 × em tudo. O Gemini 4 Argon e o Gemini 3.8 Flash (também pela
OpenRouter) custam metade dos preços da tabela até o dia indicado, quando começa o preço cheio. As
configurações também mostram os preços de cache de cada modelo, e o medidor cobra cada pedido pelos
preços do seu dia.

Todos os modelos da Anthropic, da OpenAI e da Meta aceitam as cinco profundidades de raciocínio, de
*Rápido* a *Máximo* (*Equilibrado* por padrão); o Gemini aceita três (*Muito cuidadoso* e *Máximo*
vão como *Cuidadoso*), o Grok quatro (*Máximo* vai como *Muito cuidadoso*), e um modelo acrescentado
da lista da OpenRouter as que a lista indica para ele. O Claude Fable 5.2, o GPT-6 Astra, o Gemini 4
Argon e o Muse Wonder podem pensar vários minutos num só passo, e têm tempos de espera maiores. O
Claude Fable 5.2 substituiu o Claude Fable 5.1 (uma escolha ou uma conversa guardada do 5.1 continua
com o 5.2) e só é oferecido a organizações com retenção de dados de 30 dias (senão o app explica e
sugere o Claude Opus 5.5). No Claude Fable 5.2, no Opus 5.5 e no Sonnet 5.5 um pedido que um
classificador de segurança recusa é respondido por outro modelo do lado da Anthropic, cobrado pelo
modelo que respondeu.

Os quatro clientes do Google, da xAI, da Meta e da OpenRouter foram escritos a partir da
documentação de cada empresa de 2026-11-10 e são testados contra transcrições roteirizadas que
copiam os formatos que ela documenta; não foram experimentados contra os serviços reais (nenhuma
chave foi usada no desenvolvimento deles). Os clientes da Anthropic e da OpenAI são testados da
mesma forma.

## Escolher a empresa e o modelo

As configurações do assistente mostram uma fileira com as seis empresas (um ícone de chave marca as
que têm chave salva) e, depois, os modelos da escolhida, cada um com o nível, os preços e o que é
preciso saber: um preço de lançamento e o dia em que acaba, um nível gratuito, uma regra de prompt
longo, um modelo que não lê imagens ou não usa ferramentas, um roteador, o host para onde vão os
dados. Uma chave basta: cada empresa tem a sua, digitada sob o seu botão, com um link para a página
onde a empresa emite chaves, guardada para a sessão ou, com *Lembrar a chave neste dispositivo*, no
navegador; uma segunda opinião pode usar a chave de outra empresa quando houver. O último modelo
escolhido de cada empresa fica lembrado, então voltar a uma empresa traz o modelo dela de volta.

Trocar para um modelo de outra empresa, ou entre dois modelos de uma empresa que não a Anthropic,
começa uma conversa nova: a anterior não é enviada ao modelo novo (ela fica na lista de conversas do
projeto) e o painel avisa. Entre os modelos Claude da Anthropic a conversa continua: o modelo novo a
relê inteira, sem o cache e sem o raciocínio anterior do outro modelo, e o painel informa os tokens
e o custo dessa releitura.

Um modelo que não usa ferramentas (alguns da lista da OpenRouter) só conversa: nenhuma ferramenta
vai nos pedidos dele, ele é avisado disso e responde com os dados do projeto anexados à mensagem,
indicando os menus e os passos do que deve ser feito no programa; não lê mais nada do projeto nem o
altera. Um modelo que não lê imagens não recebe nenhuma: as imagens que você anexa, as que as
ferramentas desenham e a imagem do desenho depois de uma alteração ficam de fora, e tanto você
quanto o modelo são avisados.

## Mais modelos (OpenRouter)

Com a OpenRouter escolhida, **Mais modelos…**, abaixo da lista de modelos, abre a lista completa da
OpenRouter, baixada de `openrouter.ai` quando o diálogo abre (ela é pública e não precisa de chave; a
última cópia baixada fica neste aparelho e aparece, com a data, quando não há conexão). Busque por
nome ou empresa; filtre com *Só gratuitos*, *Lê imagens* e *Usa ferramentas* (ligado de início, já
que o assistente trabalha por ferramentas); ordene *Por preço* ou *Por nome*. Cada linha mostra a
empresa, o preço em US$ por milhão de tokens (entrada / saída), a janela de contexto e se o modelo lê
imagens e usa ferramentas. Escolher uma linha acrescenta o modelo à sua lista, o escolhe na hora e o
traz de volta quando o app abre de novo; *Tirar da sua lista* o remove. Só aparecem os modelos que a
OpenRouter serve pela Responses API dela, com resposta em texto e com preço.

- **Preços e nível**: os preços de tabela que a OpenRouter publica (os do cache quando listados,
  senão o de entrada; o preço maior de prompts longos quando a lista o dá pelo tamanho do prompt;
  faixas de preço por hora do dia são ignoradas). O nível mostrado para um modelo da lista é uma
  faixa do preço de saída (topo a partir de US$ 15 por milhão de tokens, intermediário a partir de
  US$ 4, rápido abaixo), não um juízo de qualidade.
- **Roteadores**: o Auto Router escolhe um modelo a cada pedido e a OpenRouter cobra o preço desse
  modelo; o medidor precifica a resposta como o modelo que respondeu quando ele está na tabela e,
  senão, usa o valor que a OpenRouter diz ter cobrado. O Free Models Router escolhe entre modelos
  gratuitos.
- **Limite de resposta**: uma resposta pode ter os tokens de saída do provedor principal do modelo
  (32 000 quando a lista não informa), no máximo 128 000 e metade da janela de contexto. Enquanto
  um pedido roda, a OpenRouter reserva do saldo da conta o preço da maior resposta que ele permite, e
  uma conta nova ou de saldo pequeno que não cobre essa reserva é recusada; por isso os modelos fixos
  mais caros respondem no máximo 32 000 tokens (Claude Fable 5.2, GPT-6 Astra) ou 64 000 (Claude
  Opus 5.5, Grok 4.7, Muse Spark 1.3), uma reserva de cerca de US$ 1,30 por pedido.
- **Modelos gratuitos** têm limites definidos pela OpenRouter (em novembro de 2026: 20 pedidos por
  minuto e 50 por dia, ou 1000 por dia depois de comprar 10 créditos; o dia recomeça às 00:00 UTC), e
  alguns provedores por trás deles podem guardar o que recebem e treinar modelos com isso (veja
  [Armazenamento, privacidade e rede](privacy-and-network.md)). Um modelo gratuito funciona sob o
  teto de gasto como qualquer outro.

## Segunda opinião

**Segunda opinião** (o botão na última resposta) ou `/second` pede a outro modelo que confira essa
resposta. O botão lista os modelos que podem dar uma: primeiro os das outras empresas de que você
tem chave, o mais capaz de cada empresa primeiro, depois os outros modelos da empresa da própria
conversa; `/second` usa o primeiro deles. Esse modelo recebe, num só pedido sem ferramentas, os
dados do projeto (todo o texto compacto que o contexto do projeto dá), a sua pergunta e a resposta,
e diz se concorda, o que procede, o que não procede e o que conferir, com os números em que se
apoia. O pedido vai para a empresa desse modelo, com a chave dela. A revisão aparece na conversa
marcada como segunda opinião e entra no custo; o modelo da própria conversa não a lê, a não ser que
você clique em **Responder à revisão**, que a envia como material citado para o primeiro modelo
conferir, ponto por ponto, no projeto, com as ferramentas dele.

## Notas sobre cada empresa

**Anthropic e OpenAI.** Como nas versões anteriores: os modelos Claude guardam em cache o prompt e
as ferramentas, resumem as conversas longas do lado da Anthropic e, com *Ajustar o esforço a cada
etapa*, baixam o esforço dos passos simples; o GPT vai com `store: false`, é resumido do lado da
OpenAI a partir de 200 000 tokens de entrada e, no navegador, uma chave que a OpenAI recusa aparece
como falha de rede (as respostas de erro da OpenAI não trazem cabeçalho CORS).

**Google Gemini.** Crie uma chave no Google AI Studio (`aistudio.google.com/apikey`). Os pedidos vão
para `generativelanguage.googleapis.com` pela Interactions API com `store: false` (o Google não guarda
cópia para pedidos seguintes), a chave no cabeçalho `x-goog-api-key`, a conversa inteira em cada
pedido e as assinaturas do raciocínio do modelo reenviadas sem mudança. Os esforços *Rápido*,
*Equilibrado* e *Cuidadoso* vão como os níveis de raciocínio low, medium e high do Gemini. As imagens
(as vistas do desenho e do mapa, as suas fotos) vão na maior resolução de mídia, `ultra_high` (2240
tokens por imagem), ou `high` (1120) para um modelo que a recuse; PDFs vão inteiros (o Google aceita
até 50 MB ou 1000 páginas cada); cada pedido fica abaixo de 20 MB. O Google guarda sozinho em cache
as partes repetidas da conversa (a partir de 4096 tokens): um token lido desse cache custa 5 %
(Gemini 4 Argon) ou 10 % (os modelos Flash) do preço de entrada, e gravar nele é grátis; os tokens de
raciocínio são cobrados como saída. O Gemini 4 Argon responde aqui no máximo 65 536 tokens de saída.
Um bloqueio de segurança, de recitação ou de outra política encerra a resposta como recusa, com o
motivo; uma mensagem de cota diz se é para esperar (os limites por minuto do nível gratuito, com a
espera que o Google informa) ou para ativar a cobrança (um modelo sem uso gratuito, ou um projeto sem
faturamento). Os dois modelos Flash têm um nível gratuito com limites, no qual o Google pode usar o
conteúdo para melhorar seus produtos; o Gemini 4 Argon não tem.

**xAI (Grok).** Crie uma chave em `console.x.ai` (as chaves começam com `xai-`); créditos e limites
de gasto ficam na página de cobrança do console. Os pedidos vão para `api.x.ai/v1/responses` com
`store: false`, a conversa inteira a cada vez com o raciocínio criptografado reenviado sem mudança,
uma chave de cache da conversa (para os pedidos dela chegarem ao servidor que a guardou) e a
amostragem que o guia da xAI pede (temperatura 0,7, top-p 0,95). O Grok sempre raciocina; o esforço
vai como o `reasoning.effort` da xAI. O cache é automático e gravar nele é grátis; os tokens de
raciocínio são cobrados como saída; um pedido cujo prompt chega a 200 000 tokens paga o dobro dos
preços em todos os tokens. O Grok lê só JPEG e PNG, então um WebP ou GIF anexado é convertido antes,
no mesmo tamanho. Um PDF vai como o texto lido dele neste aparelho: anexado inteiro, ele ligaria a
busca em anexos da xAI, que a xAI cobra por busca. As ferramentas do lado da xAI (busca na web,
busca no X, execução de código) nunca são ligadas, e conversas longas não são resumidas do lado da
xAI. Uma chave que a xAI não conhece, uma conta sem crédito e um limite de gasto são distinguidos.

**Meta (Muse).** Crie uma chave em `dev.meta.ai/api-keys` (as chaves começam com `LLM_`) e cadastre
uma forma de pagamento em Billing. A Meta não tem um limite rígido de gasto, só um alerta por
e-mail, então o teto do próprio assistente é o limite. Os pedidos vão para `api.meta.ai/v1/responses`
com `store: false`, a conversa inteira a cada vez com o raciocínio cifrado reenviado sem mudança; as
imagens que as ferramentas desenham vão dentro dos resultados das ferramentas, as suas imagens e PDFs
na sua mensagem (a Meta aceita no máximo 50 imagens por pedido e lê o texto das 100 primeiras páginas
de um PDF). Os três modelos aceitam todos os esforços. A Meta guarda sozinha em cache os inícios de
prompt repetidos; a entrada em cache custa bem menos (Muse Wonder US$ 0,20 em vez de 4 por milhão de
tokens) e gravar no cache não é cobrado. Só os modelos *Standard* da Meta são oferecidos, com os
quais a Meta não treina; os modelos *Contributor* com desconto, com os quais ela treina, não. No
navegador a Meta não deixa a página ler o identificador do pedido nem os cabeçalhos de limite de uso,
então o teste de conexão não mostra os limites ali (o app de desktop mostra).

**OpenRouter.** Crie uma chave em `openrouter.ai/settings/keys` (as chaves começam com `sk-or-`) e
compre créditos; a OpenRouter cobra dos seus créditos e repassa cada pedido à empresa que opera o
modelo. Os pedidos vão para `openrouter.ai/api/v1/responses` com `store: false`, o raciocínio dos
modelos Claude, GPT e Gemini mantido entre as chamadas de ferramentas, o cache de prompt do Claude
ligado, um identificador de sessão tirado da conversa para que os pedidos dela fiquem num mesmo
provedor e reencontrem o cache, e dois cabeçalhos que identificam o app para a OpenRouter
(`HTTP-Referer: https://opencadirrigation.com`, `X-OpenRouter-Title: OpenCADIrrigation`), nada sobre
você. As imagens dos resultados das ferramentas vão dentro dos resultados para os modelos Claude e
GPT e logo depois deles, numa mensagem, para as outras empresas. Um PDF vai inteiro para um modelo
que lê PDFs e pelo leitor de PDF gratuito da OpenRouter para um que não lê. Os erros da OpenRouter são
lidos pelos códigos (sem crédito, orçamento da chave ou do workspace, moderação, uma regra de
proteção, o limite diário dos modelos gratuitos), e as próprias palavras da OpenRouter vêm depois da
explicação do app.

## Começar com a IA

O app abre num projeto vazio, com uma tela de início que pergunta onde fica a
área a irrigar e se você quer projetar com o assistente (não quando o endereço já diz o que abrir, um
exemplo, o tutorial ou um projeto compartilhado, nem depois de recuperar trabalho; "Não mostrar esta
tela ao iniciar" e uma chave nas configurações do assistente a desligam). O local é um endereço ou
nome de lugar buscado no OpenStreetMap (você escolhe entre os resultados) ou coordenadas em qualquer
formato usual; o projeto é georreferenciado ali e o mapa de satélite aparece. **Projetar com a IA**
abre o assistente ao lado do desenho com o local e a sua descrição, ou um pedido para começar um
projeto novo, esperando na caixa; nada é enviado antes de você clicar em Enviar. **Começar sem IA**
deixa você no projeto vazio, já georreferenciado. No celular o assistente tem um botão na barra superior, que gira enquanto ele trabalha e mostra
um ponto quando ele espera uma aprovação, uma resposta ou uma decisão sobre o plano (o botão do painel
encaixado faz o mesmo).

## Como funciona

O agente mantém uma lista de tarefas, faz perguntas em cartões com opções quando falta algo (a
tarefa espera as respostas), apresenta o seu plano e trabalha pelas ferramentas do próprio programa:
75 ferramentas enviadas em todo pedido, mais 216 operações que ele encontra e executa
(`find_operations`, `run_operation`), qualquer comando dos menus (`run_command`, com os diálogos
executados sem abrir) e cerca de 150 configurações (`get_setting`, `set_setting`), de modo que ele
alcança também as funções da 1.6.0 (estações de bombeamento, reservatórios, os diálogos de
agronomia, as análises de energia e água, os documentos técnicos e o carimbo, referências de bloco,
estados de camadas, comparações, o assistente de pontos e os pontos para locação, ilhas das áreas,
inserir projeto), as da 1.7.0 (as fileiras lidas da imagem com `detect_crop_rows` e
`apply_crop_rows`, o risco climático com `climate_risk`, a previsão de irrigação com
`irrigation_forecast`, o programa reproduzido na planta com `programme_picture`,
`export_programme_animation` e `export_programme_calendar`, o boletim de qualidade com
`design_scorecard`, a digitalização de curvas com `fit_curve_points`, `apply_curve_points` e
`export_curve_points`) e os comandos de edição (esticar, concordar, chanfrar, quebrar, unir,
explodir, converter em área). Ele lê os mesmos números dos relatórios, altera o projeto pelas mesmas funções
dos menus e diálogos (desenho, rede, catálogo, turnos, o cálculo, as suas correções, os layouts
automáticos, as análises, o orçamento, exportações), mantém as **notas de IA** do projeto
(requisitos, as suas respostas e decisões, gravadas no arquivo do projeto e editáveis nas
configurações, cada atualização um passo de desfazer), lê o manual de procedimentos do tipo de
projeto (12, escritos a partir dos exemplos da galeria) e os projetos de exemplo, encontra o local a
partir de um endereço (Nominatim do OpenStreetMap: no máximo uma busca por segundo e 8 por
conversa), define a georreferência e o mapa base, baixa o terreno e o clima pelos downloads do
próprio app e importa os desenhos e arquivos de GIS que você anexar. Ele também lê uma ficha técnica
anexada (PDF, imagem ou texto, até 20 MB) e põe os itens dela no catálogo, conferidos antes de
entrar, e escreve o memorial descritivo do projeto, que pode ser copiado ou posto no desenho como
texto. Um anexo longo não vai na mensagem: o modelo lê as partes de que precisa (`read_attachment`)
ou pede ao modelo mais barato da mesma empresa (Claude Haiku 5.5, GPT-6 Luna, Gemini 3.5
Flash-Lite, Grok 4.3 ou Muse Ember; o Claude Haiku 5.5 pela OpenRouter) que leia até 200 páginas ou
20 000 linhas dele e responda à sua pergunta (`summarize_attachment`), cujos tokens contam no
medidor e no teto de gasto. [docs/AI_TOOLS.md](../../../docs/AI_TOOLS.md), gerado a partir do mapa
de cobertura, lista o que ele alcança: toda função que um usuário alcança (ações de comando,
ferramentas de desenho, aliases, itens de menu, diálogos e suas opções, campos dos painéis, barra de
status, opções de vista) está coberta ou marcada como sem sentido para a IA, cada uma com o motivo;
um teste falha quando um comando, ferramenta, item de menu ou diálogo novo não tem rota. O prompt de
sistema traz as regras da rede, o cálculo e as permissões e indexa um manual de referência que o
modelo lê quando precisa (`read_manual`, 20 tópicos gerados a partir do código: itens e seus campos,
parâmetros de projeto, códigos de mensagem, ferramentas e operações, os valores do motor, e um
exemplo resolvido refeito com as ferramentas reais); o prompt e as definições das ferramentas ficam
em cache entre os pedidos.

## Visão

`view_snapshot` tira uma imagem do desenho sobre um mapa base: por padrão a imagem de
satélite sempre que o projeto está georreferenciado (Esri World Imagery, ou o Google com a sua chave),
para o modelo desenhar sobre o que existe de fato no terreno, e, sem georreferência, o mapa da tela; o
modelo também pode pedir o mapa da tela, um mapa de ruas ou nenhum. Os tiles são baixados fora da
tela, então a sua vista e o seu mapa base nunca mudam. O modelo também escolhe pelo que o desenho é
colorido na imagem dele (cores das camadas, pressões, velocidades, diâmetros, a menor e a maior
pressão de cada zona, ou cada zona na sua cor com o nome na válvula) e o que fica marcado nela: as
mensagens do projeto nos seus itens, numeradas como na lista de Mensagens, e as próprias alterações
da tarefa (acréscimos em ciano, mudanças em âmbar, remoções em contorno tracejado vermelho), para
conferir o que fez; a sua tela continua como está. Cada imagem informa a correspondência exata entre
pixel e mundo, e `image_to_world` converte as posições que o modelo lê nela, podendo imantá-las nas
pontas e linhas de itens existentes para que os tubos novos encontrem os antigos; uma imagem feita
antes de a georreferência mudar é recusada. `trace_region` contorna um talhão, gramado, lago ou
telhado a partir de um ponto dentro dele por análise da imagem aérea (a região cresce sobre cores e
textura semelhantes até a tolerância em que a área para de crescer, antes de vazar para o talhão
vizinho), com muito mais exatidão do que cantos escolhidos a olho, e `trace_fields` contorna todos os
talhões de uma área de uma vez (estradas, cercas vivas, manchas pequenas e regiões cortadas pela borda
da área ficam de fora). O modelo pode ampliar uma parte,
rotular os itens, desenhar formas propostas com `preview_geometry` antes de criar qualquer coisa e ler
o terreno com `terrain_picture` (sombreamento, cores por elevação, curvas de nível, declividade,
exposição), `terrain_profile` e `terrain_info`. As imagens têm o tamanho que o modelo lê pixel a
pixel: até 2576 pixels no lado maior e cerca de 3,6 megapixels no Claude Fable 5.2, Opus 5.5,
Sonnet 5.5 e Haiku 5.5 (também pela OpenRouter), senão 1568 pixels e cerca de 1,15 megapixel, com o
lado menor de no máximo 768 pixels nos modelos da OpenAI (também pela OpenRouter); imagens aéreas e
de relevo vão em JPEG, o que mantém conversas longas dentro do tamanho de uma solicitação, e fotos
anexadas são endireitadas e reduzidas a no máximo 2000 pixels de lado. No Claude Fable 5.2, Opus 5.5
e Sonnet 5.5 a linha de status mostra as notas curtas de progresso do modelo entre as etapas. O painel tem um botão que anexa uma imagem da sua vista; imagens e arquivos
também podem ser colados na caixa de mensagem (Ctrl+V) ou soltos sobre o painel. Uma configuração
(ligada por padrão) envia, depois de cada rodada de alterações, uma imagem enquadrada no que mudou,
com as alterações marcadas. Uma foto anexada que traz a posição do GPS (como os celulares gravam)
chega com o lugar onde foi tirada no projeto e o item mais próximo, e o modelo pode fixá-la no desenho
com `add_photo_comment`: um comentário de revisão naquele ponto, com uma cópia pequena da foto e o que
o modelo leu nela (a placa de uma bomba, o estado de uma caixa de válvula), mostrado nas propriedades.
Antes de exportar uma prancha de desenho, o modelo a olha com `preview_sheet`: a prancha como vai ser
impressa, com uma verificação de textos sobrepostos, pequenos demais ou cortados, de um desenho que
ocupa pouco da área de desenho ou sai dela, dos campos vazios do carimbo e do norte, da escala gráfica
e da legenda, cada achado com o lugar onde está, para corrigi-los antes.

## Apontar

"Marcar ponto" e "Marcar linha", acima da caixa de mensagem, mostram ao assistente onde:
cada clique no desenho acrescenta uma marca laranja com rótulo A, B, C… (uma linha termina com duplo
clique ou Enter; Esc a descarta), cada uma com uma nota opcional ("bomba", "adutora até aqui"). As
marcas vão com a sua próxima mensagem, com as coordenadas, e aparecem nas imagens do assistente,
então "a bomba em A, a adutora por B" é entendido com exatidão; o assistente também pode pedir que
você marque um lugar. Elas não fazem parte do projeto (nenhum passo de desfazer, nada salvo) e somem
quando você as limpa ou abre outro projeto; no celular, a janela do assistente fecha enquanto você
marca e volta quando você termina. Os comandos `MK` e `MKL` também as iniciam.

## Voz

Um botão de microfone ao lado da caixa de mensagem dita a mensagem pelo serviço de voz do
navegador, no idioma da interface (Chrome, Edge e Safari; não há no Firefox nem no app de desktop): as
palavras sendo reconhecidas aparecem num pequeno balão acima do botão e cada frase confirmada entra
na caixa no lugar do cursor, para ser lida e enviada como se fosse digitada. No primeiro uso, o app
diz para onde vai a voz.

## Conversas guardadas

Recarregar a página, ou abrir o projeto de novo mais tarde no mesmo
navegador, traz a conversa dele de volta como estava, e o modelo continua com o histórico exato de
antes; uma resposta que o fechamento da página interrompeu aparece como parada, com **Tentar de
novo**. Voltar no tempo numa conversa restaurada desfaz só a conversa (o histórico de desfazer do
projeto não sobrevive a uma recarga).

Um projeto pode guardar várias conversas: **Conversas do projeto**, no painel, as lista, a mais
recente primeiro, pela primeira mensagem; uma conversa nova deixa a atual na lista, e qualquer uma
delas abre de novo ou é apagada. `/new` começa uma nova guardando a atual, `/clear` apaga a atual. O
navegador guarda as 24 conversas salvas mais recentemente, de todos os projetos. Uma conversa é
exportada num arquivo JSON e importada de volta, sem a chave (tirada de todo texto) e sem as fotos
que você anexou (uma nota fica no lugar delas); uma conversa importada continua com o prompt de
sistema do próprio programa, então importe só conversas suas. O mesmo projeto aberto em duas abas do
navegador guarda só a conversa da primeira, e a segunda avisa.

## Controle

O que ele pode fazer é definido nas configurações: **somente leitura**; **planejar primeiro** (ele
explora só com leituras e apresenta um plano; as alterações começam depois que você o aprovar);
**perguntar antes de cada alteração** (o padrão: um cartão com Aplicar, Pular e Parar, também para
cada consulta a outro serviço, em que Enter aplica e Esc pula, e **Aplicar o resto da tarefa**
aplica esta alteração e as próximas alterações comuns da tarefa sem perguntar, com exclusões
grandes, consultas a outros serviços e exportações ainda confirmadas); ou **aplicar alterações
automaticamente** (salvar um arquivo, definir a georreferência e excluir mais de 20 itens continuam
pedindo confirmação). O cartão executa exatamente o que mostrou: a entrada de uma chamada fica
fixada quando ela é planejada, e também a seleção sobre a qual ela age. As configurações são
classificadas pelo efeito: um interruptor de vista é uma leitura, um servidor de mapa personalizado
e as configurações do próprio programa são alterações sempre confirmadas, com o host à vista. O que
você muda no desenho enquanto ele trabalha fica separado das alterações dele, que são passos
próprios em Editar → Desfazer, antes e depois dos seus. Você pode escrever enquanto ele trabalha (a
mensagem chega a ele na próxima etapa) e pará-lo a qualquer momento. Aprovar um plano com "aplicar
automaticamente" roda aquela tarefa sem perguntar; o modo escolhido nas configurações continua
valendo para as próximas. Depois de um erro ou de uma parada, a resposta oferece **Tentar de novo**
(a mesma mensagem, quando nada dela chegou ao modelo) ou **Continuar**, e as configurações quando a
correção está lá (uma chave recusada, um modelo que a chave não pode usar). Cada resposta que
alterou o projeto é uma entrada do histórico com **Desfazer estas alterações**, e cada mensagem tem
**Voltar a este ponto**, que leva o projeto (pelo histórico de desfazer) e a conversa de volta a
antes dela. Uma tarefa termina no limite de etapas (50 por padrão, até 200) ou no teto de gasto (US$
2 por padrão a preços de lista, com aviso em 80 % e um botão **Continuar** para mais um teto). O
teto é do próprio app: o modelo não vê nenhuma contagem de tokens (um orçamento de tarefa fazia ele
parar cedo e sugerir uma conversa nova), e as instruções dele dizem que há contexto de sobra. Sob
cada resposta, **Custos por passo** lista cada pedido da vez: os tokens lidos do cache e gravados
nele, os de fora dele, a saída, as imagens e os PDFs, o esforço e o que encareceu um passo (cache
não usado, troca de modelo ou de esforço, pedido grande); `/cost` diz a fração lida do cache.
Conversas longas são resumidas no servidor da empresa (na Anthropic a partir de 150 000 tokens de
entrada, depois de limpar resultados antigos de ferramentas a partir de 80 000, guardando as notas,
o plano e a lista de tarefas; na OpenAI a partir de 200 000, tirando do pedido as imagens mais
antigas); uma configuração desliga isso. Os modelos do Google, da xAI, da Meta e da OpenRouter não
são resumidos (as imagens mais antigas dos resultados de ferramentas também saem dos pedidos deles):
comece uma conversa nova quando uma ficar longa. Comandos rápidos: `/new`, `/design`, `/check`,
`/review`, `/second`, `/report`, `/quote`, `/export`, `/plan`, `/clear` e `/cost`. `/review` roda em modo somente leitura
qualquer que seja o modo: o modelo olha as zonas, as mensagens marcadas nos itens e as pressões e
velocidades sobre o desenho, lê as mensagens e as tabelas de relatório e responde com uma lista de
verificação (OK, atenção ou problema, com os números e onde corrigir cada ponto), sem alterar nada.
Instruções permanentes nas configurações valem para todas as conversas ("sempre PVC PN 80 na
adutora"), e a conversa pode ser salva em Markdown. As conversas não são salvas com o projeto, de
modo que arquivos e links compartilhados nunca levam a conversa nem as suas imagens. O que é
enviado, quando, e como as chaves são guardadas:
[Armazenamento, privacidade e rede](privacy-and-network.md).

As configurações também têm **Testar a conexão** com o modelo escolhido (um pedido mínimo pelo mesmo
caminho dos reais: se a chave, a conta e o modelo o aceitam, o tempo, os tokens, o custo, os limites
da conta e algum campo recusado), **Ajustar o esforço a cada etapa** (modelos Claude: depois de uma
rodada só de edições e leituras simples, o passo seguinte roda com esforço baixo; planejar,
calcular, conferir, imagens e erros voltam ao esforço escolhido, e a conversa em cache se mantém),
*Avisar quando o app estiver em segundo plano* (o título da aba pisca quando a tarefa espera a sua
aprovação, perguntas ou um plano, ou termina, enquanto você está em outra aba ou janela) e *Permitir
notificações do sistema* para o mesmo. O conteúdo do projeto (as notas, os textos e os nomes) chega
ao modelo como dado, nunca como instrução, e notas de IA que vieram com um arquivo escrito em outro
navegador são lidas como informação até você escolher *Usar como minhas*.
