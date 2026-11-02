# Desenho e edição

## Entidades de desenho

Linha, polilinha (aberta ou fechada), retângulo, círculo, arco, spline (curva suave pelos pontos),
hachura (linhas ou sólida), símbolo (seta norte, árvore, edificação, tanque, poço, caixa de válvula,
casa de bombas, portão, estação de filtragem), texto, cota linear, angular, radial e de diâmetro (Ø),
cota de ordenada (o X ou o Y de um ponto a partir da origem do desenho: chamada vertical cota o X,
horizontal o Y), chamada (leader), imagem (raster georreferenciada, planta em PDF ou figura
colocada à mão), curva de nível, linha de quebra, cota de ponto e área irrigada. Entidades de
revisão: **comentários** (uma nota com autor, data e indicação de resolvido) e **nuvens de
revisão** (contorno em arcos com a marca, a data e a descrição da revisão; a tabela de revisões da
prancha as lista), cada uma com a sua aba de relatório.

## Snaps

Extremidades, pontos médios, centros, quadrantes, interseções (linhas, arcos e círculos),
perpendicular e tangente a partir do ponto anterior, extensão além da ponta de uma linha, nós
hidráulicos, "sobre" tubos e laterais (o ponto mais próximo do segmento), perímetro de círculos,
grade, orto, rastreamento polar (F10) e travamento em 45° com Shift. A tolerância é em pixels,
portanto independe do zoom. O marcador muda de forma conforme o tipo de snap.

## Seleção e grips

Clique seleciona; Shift+clique alterna; janela da esquerda para a direita seleciona o que está
inteiro dentro dela e da direita para a esquerda o que ela cruza (a convenção usual dos programas de CAD). Até 60
entidades selecionadas mostram **grips**: arraste um vértice para movê-lo, arraste o ponto médio
de um segmento para inserir um vértice, Ctrl+clique num vértice para removê-lo. Com *manter
conexões* (ligado por padrão), arrastar um nó de tubo leva junto as válvulas, os itens e as rotas de
fios que o compartilham; arrastar um vértice de fio move só os fios.

## Transformações

Mover (arraste), rotacionar, espelhar (mantendo ou não a origem), escalar, deslocar (offset),
aparar e estender contra as entidades selecionadas ou visíveis, cortar tubos, matriz retangular ou
polar e alinhamento por dois pontos (move, gira e escala uma imagem ou um desenho importado de uma
vez). Inserir válvula, junção, bomba ou acessório sobre um tubo divide o tubo no ponto. Zona →
Dispositivo nas laterais selecionadas… coloca o mesmo dispositivo (regulador, registro…) na entrada
de cada lateral e fita selecionada; Converter laterais selecionadas em tubo cego mantém o traçado
sem os emissores.

## Blocos do usuário

Editar → Salvar seleção como bloco (`WBLOCK`) guarda a seleção como um bloco com nome e ponto base
(um cavalete de válvulas, um arranjo padrão de aspersores, um carimbo); Inserir bloco (`INSERT`)
coloca cópias com rotação e escala num ponto clicado ou digitado, cada inserção um passo de
desfazer, com ids novos e as camadas que faltarem. A biblioteca vai no arquivo do projeto e é
exportada como definições de bloco no DXF/DWG.

## Camadas

Cada tipo de entidade nasce na sua camada padrão (DRAWING, TEXT, DIMENSIONS, CONTOURS, BREAKLINES,
SPOT_HEIGHTS, DEM, ZONE_PIPES, MAINLINE_PIPES, SPRAYLINES, TAPES, OUTLETS, WETTED_RADII,
CONTROL_VALVES, WATER_SUPPLY, PUMPS, MISC_HYDRAULIC, JUNCTIONS, AREAS, LABELS, IMAGES, HATCHES,
SYMBOLS, PIVOTS, WIRES, CONTROLLERS, COMMENTS, REVISIONS). Camadas importadas de DXF/DWG/KML/PDF são
preservadas. Uma camada pode ficar oculta (sai do desenho, do snap e da seleção) ou bloqueada
(aparece, mas não se edita).

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
editam o projeto no lugar (detalhes, parâmetros, unidades, catálogo, gerenciamento) também geram um
passo de desfazer cada, seja qual for a forma de fechar (OK, Esc ou um clique fora): as edições
ficam, o projeto é marcado como alterado e os resultados calculados com as configurações antigas
são descartados. Um diálogo que gera algo (um layout, um bloco de laterais, as rotas dos fios) e
cada resposta do assistente de IA que alterou o projeto também são um passo.
