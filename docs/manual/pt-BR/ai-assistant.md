# Assistente de IA

Projeto → Assistente de IA… (`IA`, `AI`, `ASK`), o botão dele na barra de status ou **Perguntar à
IA** em qualquer cartão de mensagem abre um agente de IA que trabalha no projeto aberto num painel
encaixado ao lado do desenho (uma folha inferior no celular), para você ver o desenho mudar enquanto
ele trabalha. Ele usa um modelo da Anthropic (Claude, pela API Messages) ou da OpenAI (GPT, pela API
Responses), com a sua própria chave de API dessa empresa: o navegador (ou o app de desktop) chama a
API da empresa diretamente, sem servidor deste projeto no meio, e a empresa cobra o uso na sua
conta. O painel mostra os tokens de cada resposta e da conversa, com uma estimativa em US$ pelos
preços de tabela abaixo, que podem mudar.

| Empresa | Nível | Modelo | Id | US$ por milhão de tokens, entrada / saída |
|---|---|---|---|---|
| Anthropic | topo | Claude Fable 5.1 | `claude-fable-5-1` | 10 / 50 |
| Anthropic | topo | Claude Opus 5.5 (o padrão) | `claude-opus-5-5` | 4 / 20 |
| Anthropic | intermediário | Claude Sonnet 5.5 | `claude-sonnet-5-5` | 2 / 10 |
| Anthropic | rápido | Claude Haiku 5.5 | `claude-haiku-5-5` | 0,10 / 0,50 (5 × acima de 100 000 tokens de entrada) |
| OpenAI | topo | GPT-6 Astra | `gpt-6-astra` | 10 / 50 |
| OpenAI | intermediário | GPT-6.1 Sol | `gpt-6.1-sol` | 2 / 10 |
| OpenAI | intermediário, versões anteriores | GPT-6 Sol, GPT-5.6 Terra | `gpt-6-sol`, `gpt-5.6-terra` | 2 / 10, 2 / 12 |
| OpenAI | rápido | GPT-6 Luna | `gpt-6-luna` | 0,10 / 0,50 |

Pedidos à OpenAI com mais de 272 000 tokens de entrada custam 2 × na entrada e 1,5 × na saída; as
configurações também mostram os preços de cache de cada modelo. Todos os modelos aceitam cinco
profundidades de raciocínio, de rápido a máximo (equilibrado por padrão). O Claude Fable 5.1 e o
GPT-6 Astra podem pensar vários minutos num só passo, e o Claude Fable 5.1 só é oferecido a
organizações com retenção de dados de 30 dias (senão o app explica e sugere o Claude Opus 5.5). No
Claude Fable 5.1, no Opus 5.5 e no Sonnet 5.5 um pedido que um classificador de segurança recusa é
respondido por outro modelo do lado da Anthropic, cobrado pelo modelo que respondeu. Trocar para um
modelo da outra empresa, ou entre modelos da OpenAI, começa uma conversa nova; entre modelos Claude
a conversa continua.

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

O agente mantém uma lista de tarefas, faz perguntas em cartões com opções quando
falta algo (a tarefa espera as respostas), apresenta o seu plano e trabalha pelas ferramentas do
próprio programa: 73 ferramentas enviadas em todo pedido, mais 102 operações que ele encontra e
executa (`find_operations`, `run_operation`), qualquer comando dos menus (`run_command`, com os
diálogos executados sem abrir) e 134 configurações (`get_setting`, `set_setting`). Ele lê os mesmos
números dos relatórios, altera o projeto pelas mesmas funções dos menus e diálogos (desenho, rede,
catálogo, turnos, o cálculo, as suas correções, os layouts automáticos, as análises, o orçamento,
exportações), mantém as **notas de IA** do projeto (requisitos, as suas respostas e decisões,
gravadas no arquivo do projeto e editáveis nas configurações, cada atualização um passo de
desfazer), lê o manual de procedimentos do tipo de projeto (12, escritos a partir dos exemplos da
galeria) e os projetos de exemplo, encontra o local a partir de um endereço (Nominatim do
OpenStreetMap: no máximo uma busca por segundo e 8 por conversa), define a georreferência e o mapa
base, baixa o terreno e o clima pelos downloads do próprio app e importa os desenhos e arquivos de
GIS que você anexar. Ele também lê uma ficha técnica anexada (PDF, imagem ou texto, até 20 MB) e põe
os itens dela no catálogo, conferidos antes de entrar, e escreve o memorial descritivo do projeto,
que pode ser copiado ou posto no desenho como texto. [docs/AI_TOOLS.md](../../../docs/AI_TOOLS.md), gerado a
partir do mapa de cobertura, lista o que ele alcança: das 1677 funções que um usuário alcança (ações
de comando, ferramentas de desenho, aliases, itens de menu, diálogos e suas opções, campos dos
painéis, barra de status, opções de vista), 1637 estão cobertas, 40 não fazem sentido para a IA
(cada uma com o motivo) e nenhuma falta; um teste falha quando um comando, ferramenta, item de menu
ou diálogo novo não tem rota. O prompt de sistema traz as regras da rede, o cálculo e as permissões
e indexa um manual de referência que o modelo lê quando precisa (`read_manual`, 20 tópicos gerados a
partir do código: itens e seus campos, parâmetros de projeto, códigos de mensagem, ferramentas e
operações, os valores do motor, e um exemplo resolvido refeito com as ferramentas reais); o prompt e
as definições das ferramentas ficam em cache entre os pedidos.

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
pixel: até 2000 pixels e cerca de 3,6 megapixels no Claude Opus 5.5, Sonnet 5.5 e Fable 5.1, senão
1568 pixels e cerca de 1,15 megapixel, com o lado menor de no máximo 768 pixels nos modelos da
OpenAI; imagens aéreas e de relevo vão em JPEG, o que mantém conversas longas dentro do tamanho de
uma solicitação, e fotos anexadas são endireitadas e reduzidas a no máximo 2000 pixels de lado. No
Claude Opus 5.5, Sonnet 5.5 e Fable 5.1 a linha de status mostra as notas curtas de progresso do
modelo entre as etapas. O painel tem um botão que anexa uma imagem da sua vista; imagens e arquivos
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

## Controle

O que ele pode fazer é definido nas configurações: **somente leitura**; **planejar
primeiro** (ele explora só com leituras e apresenta um plano; as alterações começam depois que você
o aprovar); **perguntar antes de cada alteração** (o padrão: um cartão com Aplicar, Pular e Parar,
também para cada consulta a outro serviço); ou **aplicar alterações automaticamente** (salvar um
arquivo, definir a georreferência e excluir mais de 20 itens continuam pedindo confirmação). Você
pode escrever enquanto ele trabalha (a mensagem chega a ele na próxima etapa) e pará-lo a qualquer
momento. Aprovar um plano com "aplicar automaticamente" roda aquela tarefa sem perguntar; o modo
escolhido nas configurações continua valendo para as próximas. Depois de um erro ou de uma parada, a
resposta oferece **Tentar de novo** (a mesma mensagem, quando nada dela chegou ao modelo) ou
**Continuar**, e as configurações quando a correção está lá (uma chave recusada, um modelo que a chave
não pode usar). Cada resposta que alterou o projeto é uma entrada do histórico com **Desfazer estas
alterações**, e cada mensagem tem **Voltar a este ponto**, que leva o projeto (pelo histórico de
desfazer) e a conversa de volta a antes dela. Uma tarefa termina no limite de etapas (50 por padrão,
até 200) ou no teto de gasto (US$ 2 por padrão a preços de lista, com aviso em 80 % e um botão
**Continuar** para mais um teto). O teto é do próprio app: o modelo não vê nenhuma contagem de
tokens (um orçamento de tarefa fazia ele parar cedo e sugerir uma conversa nova), e as instruções
dele dizem que há contexto de sobra. Conversas longas são resumidas no servidor da
empresa (na Anthropic a partir de 150 000 tokens de entrada, depois de limpar resultados antigos de
ferramentas a partir de 80 000, guardando as notas, o plano e a lista de tarefas; na OpenAI a partir
de 200 000, tirando do pedido as imagens mais antigas); uma configuração desliga isso. Comandos
rápidos: `/new`, `/design`, `/check`, `/review`, `/report`, `/quote`, `/export`, `/plan`, `/clear` e
`/cost`. `/review` roda em modo somente leitura qualquer que seja o modo: o modelo olha as zonas, as
mensagens marcadas nos itens e as pressões e velocidades sobre o desenho, lê as mensagens e as tabelas
de relatório e responde com uma lista de verificação (OK, atenção ou problema, com os números e onde
corrigir cada ponto), sem alterar nada.
Instruções permanentes nas configurações valem para todas as conversas ("sempre PVC PN 80 na
adutora"), e a conversa pode ser salva em Markdown. As conversas não são salvas com o projeto, de
modo que arquivos e links compartilhados nunca levam a conversa nem as suas imagens. O que é
enviado, quando, e como as chaves são guardadas: [Armazenamento, privacidade e rede](privacy-and-network.md).
