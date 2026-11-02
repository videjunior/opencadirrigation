# Desenho e edição

## Entidades de desenho

Linha, polilinha (aberta ou fechada), retângulo, círculo, arco, spline (curva suave pelos pontos),
hachura (linhas ou sólida), símbolo (seta norte, árvore, edificação, tanque, poço, caixa de válvula,
casa de bombas, portão, estação de filtragem), texto, cota linear, angular, radial e de diâmetro (Ø),
cota de ordenada (o X ou o Y de um ponto a partir da origem do desenho: chamada vertical cota o X,
horizontal o Y), chamada (leader), imagem (raster georreferenciada, planta em PDF ou figura
colocada à mão), curva de nível, linha de quebra, cota de ponto e área irrigada. Entidades de
revisão: **comentários** (uma nota com autor, data e indicação de resolvido, opcionalmente com uma
foto de campo) e **nuvens de revisão** (contorno em arcos com a marca, a data e a descrição da
revisão; a tabela de revisões da prancha as lista), cada uma com a sua aba de relatório. Desenhar →
Foto de campo… prende uma foto ao desenho como comentário, na posição que o GPS dela dá, na posição
do aparelho ou num clique. Desenhar → Estilo de cota… define a altura do texto, as pontas (nenhuma,
seta, traço ou ponto), as casas decimais e a unidade de todas as cotas do projeto, na tela, nas
pranchas e no DXF/DWG; o padrão as desenha como nas versões anteriores. Um clique duplo num texto o
edita no lugar (Enter grava, ou Ctrl+Enter num texto de várias linhas; Esc cancela).

## Snaps

Extremidades, pontos médios, centros, quadrantes, interseções (linhas, arcos e círculos),
perpendicular e tangente a partir do ponto anterior, extensão além da ponta de uma linha, nós
hidráulicos, "sobre" tubos e laterais (o ponto mais próximo do segmento), perímetro de círculos,
grade, orto, rastreamento polar (F10) e travamento em 45° com Shift. A tolerância é em pixels,
portanto independe do zoom. O marcador muda de forma conforme o tipo de snap.

Ver → Snaps e desenho… liga e desliga cada snap de objeto (extremidade, meio, centro, quadrante, nó,
interseção, perpendicular, tangente, mais próximo, extensão) e define a distância do snap, o
rastreamento polar, o orto, o passo da grade, a **entrada dinâmica** (comprimento e ângulo junto ao
cursor: digite o comprimento, Tab, e o ângulo, ou um rumo como N45E ou um azimute como A120; Enter
põe o ponto), a **lupa** sobre o dedo nas telas de toque e *Editar durante o cálculo* (desligado por
padrão: o cálculo passa a trabalhar numa cópia, e os resultados dele, desatualizados quando você muda
algo, são descartados). Digitados durante o desenho, `END`, `MID`, `CEN`, `QUA`, `NOD`, `INT`,
`PER`, `TAN`, `NEA` ou `EXT` (e os nomes em português) escolhem o snap só do próximo ponto, como
*Snap para o próximo ponto* no menu do botão direito; `NON` o tira. Essas configurações e as das
ferramentas de desenho ficam guardadas neste navegador para as próximas visitas e abas.

## Seleção e grips

Clique seleciona; Shift+clique alterna; janela da esquerda para a direita seleciona o que está
inteiro dentro dela e da direita para a esquerda o que ela cruza (a convenção usual dos programas de CAD).
Editar → Selecionar ▸ acrescenta *Selecionar semelhantes* (mesmo tipo e mesmo item do catálogo, ou
mesmo tipo na mesma camada), *Seleção rápida…* (por tipo, camada, item do catálogo, zona, ou uma
faixa de comprimento, área, cota, pressão ou diâmetro, para substituir, somar, retirar ou filtrar a
seleção), tudo na camada atual, e as ferramentas **laço** (à mão ou por cliques) e **cerca**; a aba
Camadas seleciona os itens de uma camada. Quando a seleção mistura tipos, Propriedades mostra uma
ficha por tipo e edita um tipo por vez; um campo com valores diferentes fica vazio e qualquer número
digitado vale para todos. Até 60
entidades selecionadas mostram **grips**: arraste um vértice para movê-lo, arraste o ponto médio
de um segmento para inserir um vértice, Ctrl+clique num vértice para removê-lo. Com *manter
conexões* (ligado por padrão), arrastar um nó de tubo leva junto as válvulas, os itens e as rotas de
fios que o compartilham; arrastar um vértice de fio move só os fios.

## Transformações

Mover (arraste, ou Mover `M` com ponto-base e destino clicados ou digitados), Copiar com ponto-base
(`CO`, repetido a partir do mesmo ponto-base até Esc), rotacionar, espelhar (mantendo ou não a
origem; os textos continuam legíveis e os símbolos são refletidos), escalar, deslocar (offset; a
prévia é a cópia que ele cria), aparar e estender contra as entidades selecionadas ou visíveis (com
segmentos de fechamento, círculos, arcos e splines), cortar tubos, matriz retangular ou polar e
alinhamento por dois pontos (move, gira e escala uma imagem ou um desenho importado de uma vez).
Rotacionar, Escalar e Deslocar aceitam o ângulo, o fator ou a distância digitados na linha de
comando. Editar → Geometria ▸ tem **esticar** (por janela), **concordância** (curva circular
simples, T = R·tan(Δ/2)) e **chanfro** entre duas linhas ou num vértice, **quebrar em dois pontos**,
**unir** (linhas, polilinhas e arcos, tubos do mesmo tipo, fios, curvas de nível e linhas de quebra
com pontas coincidentes, nunca através de uma válvula), **explodir** (polilinhas, hachuras, splines,
chamadas, tubos, laterais e fitas em segmentos, mantendo os emissores), **converter em área**
(polilinhas fechadas, círculos, hachuras e splines fechadas) e **Subtrair da área**: uma forma
fechada selecionada com uma área irrigada vira ilha dela (um lago, um prédio), um recorte, ou a
divide, e sai do desenho; *Remover as ilhas da área* devolve o contorno inteiro. **Alongar** (`LEN`)
muda um item aberto na ponta mais próxima por uma diferença, até um comprimento total ou por uma
porcentagem (os emissores de uma lateral ficam onde estavam); **Contorno por clique interno** (`BO`)
faz a menor região que as linhas desenhadas fecham em volta de um ponto, como polilinha ou área
irrigada; a ordem de desenho põe a seleção na frente ou atrás (`TOFRONT`, `TOBACK`). Cada edição é
um passo de desfazer com nome próprio. Medir (`ME`) mantém o último resultado no desenho e no seu
painel, com um botão para copiá-lo: a distância entre dois pontos, o comprimento ao longo de vários
pontos ou a área e o perímetro de um contorno (modos D, M e A). Inserir válvula, junção, bomba ou
acessório sobre um tubo divide o tubo no ponto. Zona → Dispositivo nas laterais selecionadas… coloca
o mesmo dispositivo (regulador, registro…) na entrada de cada lateral e fita selecionada; Converter
laterais selecionadas em tubo cego mantém o traçado sem os emissores.

## Blocos do usuário

Editar → Salvar seleção como bloco (`WBLOCK`) guarda a seleção como um bloco com nome e ponto base
(um cavalete de válvulas, um arranjo padrão de aspersores, um carimbo); Inserir bloco (`INSERT`)
coloca cópias com rotação e escala num ponto clicado ou digitado, cada inserção um passo de
desfazer, com ids novos e as camadas que faltarem. A biblioteca vai no arquivo do projeto e é
exportada como definições de bloco no DXF/DWG.

Um bloco de itens de desenho (linhas, polilinhas, círculos, arcos, splines, hachuras, símbolos,
textos, cotas, chamadas) pode entrar como **referência de bloco**: a definição desenhada onde a
referência está, com a sua rotação e escala. Textos escritos `{TAG}` na seleção viram **atributos**,
cujos valores cada referência guarda (as Propriedades os editam); um bloco marcado para contar na
lista de materiais lista ali as suas referências. Ao salvar um bloco, a seleção pode ser trocada por
uma referência a ele, e redefinir um bloco atualiza todas as suas referências. Editar → Blocos ▸
edita um bloco no lugar (`BEDIT`: mude as cópias e use *Salvar bloco*), explode referências em itens
simples e exporta ou importa a biblioteca de blocos (`.oci-blocks.json`, ou os blocos de outro
arquivo de projeto). Um bloco com itens hidráulicos ou de terreno sempre entra como cópias, que o
cálculo enxerga; as referências são passivas para o cálculo e vão para o DXF/DWG como INSERT com
ATTRIB.

## Camadas

Cada tipo de entidade nasce na sua camada padrão (DRAWING, TEXT, DIMENSIONS, CONTOURS, BREAKLINES,
SPOT_HEIGHTS, DEM, ZONE_PIPES, MAINLINE_PIPES, SPRAYLINES, TAPES, OUTLETS, WETTED_RADII,
CONTROL_VALVES, WATER_SUPPLY, PUMPS, MISC_HYDRAULIC, JUNCTIONS, AREAS, LABELS, IMAGES, HATCHES,
SYMBOLS, PIVOTS, WIRES, CONTROLLERS, COMMENTS, REVISIONS). Camadas importadas de DXF/DWG/KML/PDF são
preservadas. Uma camada pode ficar oculta (sai do desenho, do snap e da seleção) ou bloqueada
(aparece, mas não se edita). Ver → Camadas ▸ isola as camadas da seleção (ou a atual) e mostra todas
as camadas de novo (`LAYISO`, `LAYUNISO`), e *Estados de camadas…* guarda estados com nome de quais
camadas aparecem e quais estão bloqueadas ("prancha hidráulica", "prancha elétrica") para restaurar
numa escolha; Editar → Mover para a camada atual (`LAYCUR`). As faixas de carretel e os conjuntos de
sulcos nascem nas camadas TRAVELLERS e SURFACE_IRRIGATION, criadas com o primeiro deles.

## Rótulos

Ver → Rótulos mostra nomes e diâmetros; Ver → Rótulos condicionais… cria regras que escrevem um
resultado junto aos tubos (velocidade, vazão, pressão, perda de carga, diâmetro), emissores
(pressão, vazão) ou válvulas (vazão, pressão, pressão a jusante) onde ele fica acima ou abaixo de um
valor, ou sempre, numa cor própria (velocidade acima de 1,5 m/s em vermelho, por exemplo). As regras
vão com o projeto.

## Histórico

Cada ação gera um estado nomeado (adicionar linha, mover 3 itens, projetar, importar…). Desfazer e
refazer percorrem até 150 estados (menos em desenhos muito grandes: as cópias guardadas ficam abaixo
de 400 000 entidades); o painel Histórico permite saltar para qualquer um deles. Os diálogos que
editam o projeto no lugar (detalhes, parâmetros, unidades, catálogo, gerenciamento, orçamento,
rótulos condicionais, carimbo) geram um passo de desfazer cada quando fechados com OK: as edições
ficam, o projeto é marcado como alterado e os resultados calculados com as configurações antigas
são descartados; Cancelar, Esc ou um clique fora devolvem tudo como estava. Um diálogo que gera algo (um layout, um bloco de laterais, as rotas dos fios) e
cada resposta do assistente de IA que alterou o projeto também são um passo; uma análise que não muda
nenhum item não grava passo.

## Comparar cópias

Arquivo → Comparar com… confronta o projeto aberto com outra aba, uma versão guardada no navegador
ou um arquivo: os itens novos, removidos e alterados (casados pelo id, cada um mostrado no desenho),
as configurações que diferem (dados do projeto, parâmetros, catálogo, camadas, turnos, blocos) e os
números principais dos dois (itens, comprimentos de tubos e de laterais, emissores, válvulas, área
irrigada e, com resultados, a vazão máxima, as pressões e o custo dos materiais). Arquivo → Trazer
comentários de uma cópia… acrescenta os comentários de revisão e as nuvens de revisão de uma cópia
revisada (casados pelo id, senão pelo lugar e pelo texto), para revisar um projeto sem servidor.
Arquivo → Histórico de versões compara uma versão com o projeto e a abre numa aba própria.
