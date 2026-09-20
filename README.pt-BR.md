<p align="center"><img src="web/brand/logo-horizontal.png" width="560" alt="OpenCADIrrigation"></p>

<p align="center"><a href="https://opencadirrigation.com">opencadirrigation.com</a> · <a href="https://opencadirrigation.com/en/">English</a> · <a href="https://opencadirrigation.com/es/">Español</a></p>

<p align="center"><a href="README.md">English (canonical)</a> · <strong>Português</strong></p>

# OpenCADIrrigation

CAD aberto, escrito em Flutter/Dart, para projeto de sistemas de irrigação pressurizada:
desenho, rede hidráulica, dimensionamento, relatórios e plotagem, direto no navegador, sem
instalação, sem servidor e sem cadastro. Os projetos ficam no seu computador.

> Esta é a tradução em português do README. A versão canônica, mantida em inglês, é
> [README.md](README.md). O estudo técnico está em [docs/TECHNICAL_STUDY.md](docs/TECHNICAL_STUDY.md)
> (inglês) e [docs/PESQUISA.pt-BR.md](docs/PESQUISA.pt-BR.md) (português). O código, seus comentários e a
> documentação do motor são em inglês.

---

## Sumário

1. [Visão geral](#1-visão-geral)
2. [Começando em cinco minutos](#2-começando-em-cinco-minutos)
3. [Fluxo de projeto](#3-fluxo-de-projeto)
4. [Interface](#4-interface)
5. [Desenho e edição](#5-desenho-e-edição)
6. [Rede hidráulica](#6-rede-hidráulica)
7. [Catálogo de componentes](#7-catálogo-de-componentes)
8. [Terreno](#8-terreno)
9. [Cálculo e dimensionamento](#9-cálculo-e-dimensionamento)
10. [Relatórios, plotagem e exportação](#10-relatórios-plotagem-e-exportação)
11. [Formatos de arquivo](#11-formatos-de-arquivo)
12. [Armazenamento, privacidade e rede](#12-armazenamento-privacidade-e-rede)
13. [Idiomas e site](#13-idiomas-e-site)
14. [Arquitetura do código](#14-arquitetura-do-código)
15. [Desenvolvimento](#15-desenvolvimento)
16. [Testes](#16-testes)
17. [Limitações conhecidas e roteiro](#17-limitações-conhecidas-e-roteiro)
18. [Contribuindo](#18-contribuindo)
19. [Referências](#19-referências)

---

## 1. Visão geral

### O que é

Um único aplicativo que cobre o ciclo completo de um projeto de irrigação pressurizada:

- **Desenho CAD 2D** com camadas, snaps, cotas, hachuras, símbolos e atalhos no estilo AutoCAD.
- **Rede hidráulica** desenhada sobre o CAD: fontes de água, bombas, linha principal, válvulas de
  zona, laterais com emissores, fitas e tubos gotejadores, filtros, reguladores, hidrômetros,
  junções e pivôs centrais.
- **Motor hidráulico** em Dart puro: perda de carga por Hazen-Williams ou Darcy-Weisbach, perdas
  localizadas, emissores `q = k·H^x`, solver de rede pelo Global Gradient Algorithm (o mesmo do
  EPANET), bombas, válvulas reguladoras, golpe de aríete, lavagem de fitas.
- **Dimensionamento automático** de laterais, submains e linha principal por programação linear
  (custo anualizado de tubos + energia, janela de pressão dos emissores, classe dos tubos,
  telescopagem) ou pelo método clássico de velocidade máxima.
- **Terreno**: curvas de nível, cotas, modelo digital por triangulação, elevação baixada da
  internet a partir de uma coordenada, perfis e linha piezométrica.
- **Saídas**: relatórios de zonas, tubos, emissores, turnos, lista de materiais com conexões,
  requisitos hídricos e programa do controlador; prancha em PDF; DXF, DWG, SVG, KML, KMZ, GeoJSON,
  Excel, CSV.
- **Catálogos abertos** de fabricantes em JSON, carregáveis por arquivo ou URL.

### Para quem

Projetistas de irrigação agrícola e paisagística, agrônomos, engenheiros, revendas, professores e
estudantes. O tutorial interativo e a galeria de exemplos permitem começar sem ler manual.

### Princípios

| Princípio | O que significa na prática |
|---|---|
| Aberto | Código, formato de projeto (`.oci.json`), catálogos (`.oci.cat`) e exemplos são arquivos legíveis, documentados neste repositório. |
| No navegador | Chrome, Edge, Firefox e Safari, em computador, tablet e celular; instalável como PWA. Também compila para desktop (macOS, Windows, Linux). |
| Sem servidor | Nada é enviado a lugar nenhum. Projetos ficam no navegador e em arquivos locais. Só a elevação online e os mapas base acessam a internet, quando pedidos. |
| Motor transparente | Cada fórmula está documentada no código e no [estudo técnico](docs/PESQUISA.pt-BR.md), com testes que a comparam a valores de referência. |
| 20 idiomas | Interface em português, inglês, espanhol, chinês, hindi, árabe, francês, bengali, russo, urdu, indonésio, alemão, japonês, marati, vietnamita, télugo, hauçá, turco, panjabi e suaíli; o app abre no idioma do sistema. |

---

## 2. Começando em cinco minutos

1. Abra [opencadirrigation.com](https://opencadirrigation.com). Na primeira visita aparece a tela
   de boas-vindas com a **galeria de exemplos** e o botão do **tutorial interativo**.
2. Escolha um exemplo (o pomar é o padrão) ou comece do zero.
3. Pressione **F5** (ou o botão ▶ no canto superior direito). O cálculo roda fora da thread da
   interface; um cartão de progresso mostra a etapa atual (zona a zona, linha principal, lavagem,
   golpe de aríete, materiais). A tela continua utilizável durante o cálculo.
4. Leia os resultados no painel de **Relatórios** (F2): resumo das zonas, tubos com diâmetros e
   pressões, emissores, linha principal e duty das fontes, lista de materiais, requisitos hídricos,
   linha piezométrica, mensagens.
5. Passe o mouse sobre um tubo para ver diâmetro, vazão, velocidade e perda; selecione uma lateral
   e abra a aba **Linha piezométrica**; troque a sobreposição do desenho em Ver (velocidade,
   pressão, diâmetros, mínimos e máximos).
6. Exporte: Arquivo → Exportar desenho (PDF com prancha, DXF, DWG…) ou Exportar relatório
   (PDF, Excel, CSV, TXT). Salve o projeto com **Ctrl+S** (`.oci.json`).

### Galeria de exemplos

| id | Projeto | Conteúdo | Zonas |
|---|---|---|---|
| `orchard` | Pomar | Microaspersão em citros e gotejamento em uva, poço, bomba e filtro, terreno em declive | 2 |
| `garden` | Jardim residencial | Sprays pop-up no gramado da frente, rotores atrás, gotejamento nos canteiros; rede pública com hidrômetro e anti-refluxo | 3 |
| `sportsField` | Campo de futebol | 105 × 68 m, aspersores de impacto em cinco linhas, reservatório, bomba, turnos noturnos | 5 |
| `rowCrop` | Lavoura gotejada | Quatro talhões de tomate com fita, submains com válvulas, filtro de tela, bomba, declive de 1 % | 4 |
| `pivot` | Pivô central | Pivô de 300 m em milho, adutora, poço e bomba; relatório de torres, vãos e bocais | 1 pivô |
| `greenhouse` | Estufa de hortaliças | Quatro túneis de pimentão com tubo gotejador autocompensante, reservatório, bomba pequena e filtro de discos | 4 |
| `nursery` | Viveiro de mudas | Três canteiros com microaspersores suspensos em malha 4 × 4 m, caixa d’água elevada, bomba pequena e filtro de discos | 3 |
| `coffee` | Cafezal em curvas de nível | Três talhões em encosta com laterais curvas que seguem as curvas de nível (bloco guiado), tubo gotejador PC, poço e bomba | 3 |
| `bananas` | Bananal | Dois talhões com microaspersores autocompensantes em 5 × 5 m, poço com bomba submersa e filtro de discos | 2 |
| `sugarcane` | Cana-de-açúcar subsuperficial | Tubo gotejador PC de 20 mm enterrado a 0,3 m, laterais de 180 m, submains enterrados, filtro de tela e ventosa | 2 |
| `gravity` | Gotejamento por gravidade | Reservatório 40 m acima dos talhões, sem bomba: registro, válvula reguladora de pressão e filtro na adutora | 2 |
| `pasture` | Pastagem em aspersão | Três piquetes com linhas de aspersores de impacto em 12 × 18 m, reservatório, bomba e válvula de retenção | 3 |
| `golf` | Buraco de golfe | Tee com sprays, fairway com rotores em malha triangular e green com rotores no perímetro, lago e bomba | 4 |
| `sectorPivot` | Pivô setorial com canhão | Pivô de 250 m que gira 270° com canhão final de 12 m³/h, lago, bomba de 30 cv e registro | 1 pivô |
| `linear` | Pivô linear | Lateral móvel de 392 m percorrendo 800 m ao longo de um canal, captação com bomba de 30 cv | 1 linear |

Os exemplos abrem pela tela de boas-vindas (Ajuda → Boas-vindas e galeria de exemplos…), pelo
menu Arquivo → Exemplos e pela URL. Os mesmos projetos estão em [examples/](examples/) como
`.oci.json` em português, inglês e espanhol.

### Parâmetros de URL

| Parâmetro | Efeito |
|---|---|
| `?example=garden` | Abre o exemplo indicado (`orchard`, `garden`, `sportsField`, `rowCrop`, `pivot`, `greenhouse`, `nursery`, `coffee`, `bananas`, `sugarcane`, `gravity`, `pasture`, `golf`, `sectorPivot`, `linear`). |
| `?design=1` | Projeta ao carregar. |
| `?tutorial=N` | Abre o tutorial interativo no passo N. |
| `?lang=pt` (qualquer código da seção 13) | Idioma desta visita (não altera a preferência salva). |
| `/en/`, `/es/` | Páginas de entrada em inglês e espanhol, com o mesmo efeito de `?lang`. |

---

## 3. Fluxo de projeto

O fluxo segue a prática consolidada de projeto de irrigação (inventário e terreno, layout,
zonas, gerenciamento, linha principal, materiais e plotagem), adaptada a um app de navegador.

1. **Detalhes do projeto** (Arquivo → Detalhes): nome, cliente, obra, projetista e notas, que vão
   para o carimbo da prancha e para os relatórios. Unidades (métrico ou US) em Ferramentas → Unidades.
2. **Informações de fundo**: importe a base (DXF, DWG, KML/KMZ, SHP, CSV de topografia,
   GeoTIFF, imagem de satélite) ou desenhe limites, edificações e estradas. Imagens fora de
   escala se ajustam com Alinhar por 2 pontos (AL). Georreferencie o projeto (Arquivo →
   Georreferência) quando quiser mapas base, elevação online ou exportação KML/GeoJSON.
3. **Terreno**: desenhe curvas de nível (CT) e cotas de ponto (SP), importe um levantamento, um
   GeoTIFF de elevação, ou baixe a elevação da internet a partir de uma coordenada. Gere curvas de
   nível do modelo e confira em 3D.
4. **Layout hidráulico**: fonte de água (WS), bomba (PU), linha principal (MP), válvulas de zona (V),
   e, a jusante de cada válvula, tubos de zona (ZP), laterais (SL), fitas (DT), emissores (OUT),
   acessórios (F). Os geradores de **bloco de laterais** (B) e de **grade de aspersores** (AH)
   fazem o trabalho repetitivo. Áreas irrigadas (AR) trazem cultura, eficiência e balanço hídrico.
5. **Gerenciamento** (Projeto → Gerenciamento): turnos de operação (quais válvulas abrem juntas,
   horário e duração). Sem turnos definidos, cada válvula vira um turno.
6. **Verificação** (Projeto → Verificar projeto): itens desconectados, tubos que se cruzam sem
   junção, pontas soltas, zonas sem emissores, catálogo faltando, terreno ausente.
7. **Projetar** (F5): zonas, linha principal, telescopagem, lavagem, golpe de aríete e materiais.
   Também é possível projetar só as zonas, só a linha principal, ou apenas analisar com os
   diâmetros atuais.
8. **Relatórios e plotagem**: painel de relatórios, prancha em PDF com carimbo, legenda, seta
   norte, escala gráfica e lista de materiais; exportações para outros CADs, GIS e planilhas.

---

## 4. Interface

### Layout (tela larga)

- **Barra de menus** no topo; à direita, os botões ▶ Projetar e Salvar (âmbar quando há alterações).
- **Abas de projeto** logo abaixo: vários projetos abertos ao mesmo tempo (Ctrl+Alt+N nova aba,
  Ctrl+Alt+W fecha, Ctrl+Alt+←/→ alterna). Copiar e colar (Ctrl+C/X/V) funciona entre abas e
  entre janelas do navegador, levando camadas e itens de catálogo que faltem no destino.
- **Paleta de ferramentas** à esquerda, por grupos (navegação, desenho, terreno, zona, linha
  principal, edição).
- **Canvas** ao centro, com grade, snaps, sobreposições e cartão de progresso do cálculo.
- **Painel lateral** à direita com três abas: **Propriedades** do item selecionado (com resultados
  hidráulicos após o cálculo e o envelope de posição do submain para laterais), **Camadas**
  (visibilidade, bloqueio, cor, renomear, criar, remover) e **Histórico** (linha do tempo de
  estados, como no Photoshop: clique para voltar ou avançar).
- **Relatórios** embaixo do canvas (F2), redimensionável.
- **Barra de status** com coordenadas do cursor, snap ativo, comando digitado, dica da ferramenta,
  interruptores (snap, orto, grade) e a versão do app.

### Layout compacto (celular e tablet)

Abaixo de 700 px de largura a tela muda: menu ☰ no topo, barra de ferramentas por grupos embaixo,
botões Concluir/Cancelar no lugar de Enter/Esc, propriedades e relatórios em painéis deslizantes.
Pinça para zoom, dois dedos para mover, um dedo desenha.

### Menus

| Menu | Itens |
|---|---|
| Arquivo | Novo projeto, Nova aba, Fechar aba, Abrir projeto, Projetos recentes, Salvar, Versões, Autosave (liga/desliga), Exemplos ▸, Importar (DXF, DWG, KML/KMZ, SHP, CSV/XYZ, imagens, GeoTIFF), Georreferenciar imagem selecionada, Alinhar por 2 pontos, Exportar desenho ▸ (DXF, DWG, PDF, SVG, KML, KMZ, GeoJSON), Exportar relatório ▸ (CSV, TXT, XLSX, PDF, programa do controlador), Detalhes do projeto, Georreferência |
| Editar | Desfazer, Refazer, Selecionar tudo, Copiar, Recortar, Colar, Duplicar, Excluir, Transformar ▸ (rotacionar, espelhar, escalar, deslocar, aparar, estender, cortar tubo, alinhar imagem, matriz) |
| Ver | Enquadrar, Zoom +/−, Grade, Rótulos, Raios molhados, Grips, Sobreposição (nenhuma, velocidade, pressão, diâmetros, mín/máx de pressão), Mapa base ▸ (nenhum, OpenStreetMap, OpenTopoMap, CARTO, Esri imagem/ruas/topográfico, Google Maps mapa/satélite/híbrido/relevo com a sua própria chave de API, URL XYZ personalizada; exige georreferência), Chave da API do Google Maps…, URL do mapa personalizado…, Idioma ▸ |
| Desenhar | Linha, Polilinha, Retângulo, Círculo, Arco, Spline, Hachura, Símbolo, Texto, Cota linear, Cota angular, Cota radial, Chamada (leader), Medir |
| Zona | Tubo de zona, Lateral (sprayline), Fita gotejadora, Emissor, Válvula de zona, Acessório, Junção, Bloco de laterais, Grade de aspersores, Envelope de posição do submain |
| Linha principal | Fonte de água, Tubo principal, Bomba, Seleção de bomba, Pivô central / linear |
| Projeto | Parâmetros de projeto, Catálogo de componentes, Gerenciamento (turnos), Terreno ▸ (curva de nível, cota de ponto, perfil, baixar elevação da internet, gerar curvas do modelo, vista 3D, limpar perfil), Verificar projeto, Projetar zonas, Projetar linha principal, Projetar tudo, Analisar (sem redimensionar), Limpar resultados |
| Relatórios | Mostrar/ocultar painel e suas abas |
| Ferramentas | Calculadora de lateral, Bomba e curva do sistema, Golpe de aríete, Unidades |
| Ajuda | Tutorial interativo, Boas-vindas e galeria de exemplos, Atalhos de teclado, Sobre |

### Atalhos de teclado

Com o desenho em foco, digite o alias e **Enter** ou **Espaço**; um alias completo também executa
sozinho após uma pausa. Os aliases aceitam nomes em português, inglês e espanhol (por exemplo
`LINHA`, `LINE`, `LINEA`). A lista completa está em Ajuda → Atalhos de teclado.

| Grupo | Aliases |
|---|---|
| Navegação | `S` seleção · `P` pan · `Z` / `ZE` enquadrar · `ZI` / `ZO` zoom |
| Desenho | `L` linha · `PL` polilinha · `REC` retângulo · `C` círculo · `A` arco · `SPL` spline · `H` hachura · `SY` / `I` símbolo · `T` / `MT` texto · `D` cota · `DAN` cota angular · `DRA` cota radial · `LE` chamada · `ME` / `DI` medir |
| Terreno | `CT` curva de nível · `SP` cota de ponto · `PR` perfil · `AR` área irrigada |
| Edição | `RO` rotacionar · `MI` espelhar · `SC` escalar · `O` deslocar · `TR` aparar · `EX` estender · `CUT` / `BR` cortar tubo · `ARRAY` matriz · `E` apagar · `CO` copiar · `PA` colar · `U` desfazer · `REDO` · `ALL` selecionar tudo · `DUP` duplicar · `AL` alinhar por 2 pontos |
| Zona | `ZP` tubo de zona · `SL` lateral · `DT` fita · `OUT` / `EM` emissor · `V` válvula · `F` acessório · `J` junção · `B` bloco · `AH` grade de aspersores · `FE` envelope do submain |
| Linha principal | `MP` tubo principal · `WS` fonte · `PU` bomba · `PV` pivô |
| Projeto e arquivos | `RUN` projetar · `CHK` verificar · `REP` relatórios · `SAVE` · `OPEN` · `OS` snap · `OR` orto · `GS` snap à grade · `GR` grade |

| Tecla | Ação |
|---|---|
| F2 | Mostra/oculta relatórios |
| F3 | Liga/desliga snap a objetos |
| F5 | Projetar tudo |
| F7 | Grade |
| F8 | Orto |
| F9 | Snap à grade |
| Home | Enquadrar |
| Enter | Conclui a polilinha/lateral em desenho; ao selecionar, repete a última ferramenta |
| Esc | Cancela a ferramenta ou limpa a seleção |
| Del | Apaga a seleção |
| Shift (segurado) | Trava o segmento em 0°, 45°, 90° |
| Ctrl+Z / Ctrl+Y | Desfazer / refazer |
| Ctrl+A, Ctrl+D | Selecionar tudo, duplicar |
| Ctrl+C / X / V | Copiar, recortar, colar (também entre abas e janelas) |
| Ctrl+S, Ctrl+O, Ctrl+I | Salvar, abrir, importar |
| Ctrl+Alt+N / W / ← / → | Nova aba, fechar aba, alternar abas |

Os atalhos são capturados nativamente (listener de teclado da janela no navegador,
`HardwareKeyboard` no desktop) e funcionam com qualquer widget em foco, exceto quando um menu ou
um diálogo está aberto.

---

## 5. Desenho e edição

### Entidades de desenho

Linha, polilinha (aberta ou fechada), retângulo, círculo, arco, spline (curva suave pelos pontos),
hachura (linhas ou sólida), símbolo (seta norte, árvore, edificação, tanque, poço, caixa de válvula,
casa de bombas, portão, estação de filtragem), texto, cota linear, angular e radial, chamada (leader),
imagem (raster georreferenciada ou colocada à mão), curva de nível, cota de ponto e área irrigada.

### Snaps

Extremidades, pontos médios, nós hidráulicos, "sobre" tubos e laterais (o ponto mais próximo do
segmento), perímetro de círculos, grade, orto e travamento em 45° com Shift. A tolerância é em
pixels, portanto independe do zoom. O marcador muda de forma conforme o tipo de snap.

### Seleção e grips

Clique seleciona; Shift+clique alterna; janela da esquerda para a direita seleciona o que está
inteiro dentro dela e da direita para a esquerda o que ela cruza (convenção AutoCAD). Até 12
entidades selecionadas mostram **grips**: arraste um vértice para movê-lo, arraste o ponto médio
de um segmento para inserir um vértice, Ctrl+clique num vértice para removê-lo.

### Transformações

Mover (arraste), rotacionar, espelhar (mantendo ou não a origem), escalar, deslocar (offset),
aparar e estender contra as entidades selecionadas ou visíveis, cortar tubos, matriz retangular ou
polar e alinhamento por dois pontos (move, gira e escala uma imagem ou um desenho importado de uma
vez). Inserir válvula, junção, bomba ou acessório sobre um tubo divide o tubo no ponto.

### Camadas

Cada tipo de entidade nasce na sua camada padrão (DRAWING, TEXT, DIMENSIONS, CONTOURS,
SPOT_HEIGHTS, ZONE_PIPES, MAINLINE_PIPES, SPRAYLINES, TAPES, OUTLETS, WETTED_RADII,
CONTROL_VALVES, WATER_SUPPLY, PUMPS, MISC_HYDRAULIC, JUNCTIONS, AREAS, LABELS, IMAGES, HATCHES,
SYMBOLS, PIVOTS). Camadas importadas de DXF/DWG/KML são preservadas. Uma camada pode ficar oculta
(sai do desenho, do snap e da seleção) ou bloqueada (aparece, mas não se edita).

### Histórico

Cada ação gera um estado nomeado (adicionar linha, mover 3 itens, projetar, importar…). Desfazer e
refazer percorrem até 50 estados; o painel Histórico permite saltar para qualquer um deles.

---

## 6. Rede hidráulica

### Entidades hidráulicas

| Entidade | Alias | Camada | Papel no cálculo |
|---|---|---|---|
| Fonte de água | `WS` | WATER_SUPPLY | Origem da linha principal. Pressão calculada (poço com nível negativo, reservatório com altura positiva) ou fixa (rede pública com pressão e vazão de projeto e máximas). |
| Bomba | `PU` | PUMPS | Curva H(Q) do catálogo, com relação de velocidade; ponto de operação no cálculo dos turnos. |
| Tubo principal | `MP` | MAINLINE_PIPES | Da fonte às válvulas; diâmetro fixo ou dimensionado (`computerSized`). |
| Válvula de zona | `V` | CONTROL_VALVES | Separa linha principal e zona; define o nome da zona; pode ter pressão de jusante fixa para análise detalhada. |
| Tubo de zona | `ZP` | ZONE_PIPES | Submains e distribuidores a jusante da válvula. |
| Lateral (sprayline) | `SL` | SPRAYLINES | Tubo com emissores igualmente espaçados: emissor e bocal do catálogo, espaçamento, deslocamento do primeiro, arco, altura da haste, profundidade. |
| Fita / tubo gotejador | `DT` | TAPES | Emissores integrados definidos pelo item do catálogo; pressão de entrada, regulada ou não, vazão de lavagem. |
| Emissor individual | `OUT` | OUTLETS | Aspersor, microaspersor, gotejador, canhão ou ponto de demanda sobre um tubo de zona (ou de linha principal, quando é uma zona própria). |
| Acessório | `F` | MISC_HYDRAULIC | Registro, filtro, regulador de pressão (com ajuste), hidrômetro, anti-refluxo, ventosa, válvula de retenção; em zona ou linha principal. |
| Junção | `J` | JUNCTIONS | Nó explícito, com cota fixa opcional. |
| Área irrigada | `AR` | AREAS | Polígono com cultura, lâmina líquida ou balanço hídrico (ETo, Kc, CAD, profundidade radicular, fração de esgotamento), eficiência, fração molhada, emissores por planta. |
| Pivô central / linear | `PV` | PIVOTS | Máquina com raio, vãos, profundidade de lâmina, ciclo, pressão final, canhão final, custo. Demanda sobre a linha principal. |

### Regras de conexão

- **Vértices coincidentes conectam.** Dois tubos que compartilham um vértice (dentro da tolerância
  de conexão, 0,05 m por padrão) formam um nó. Um tubo que termina no meio de outro é ligado por um
  tê automático. Emissores, válvulas, bombas e acessórios colocados sobre um tubo dividem o tubo.
- **A válvula separa os mundos.** Tudo a jusante de uma válvula de zona pertence àquela zona; a
  linha principal vai da fonte até as válvulas. Itens de zona não se ligam a itens de linha
  principal sem uma válvula entre eles.
- **Fitas e laterais não se tocam entre zonas.** Como vértices coincidentes conectam, as pontas de
  fitas de talhões vizinhos devem ficar afastadas (uma faixa de manejo entre blocos), ou as duas
  zonas serão calculadas como uma só. A verificação de projeto avisa sobre itens desconectados,
  tubos cruzados sem junção e pontas soltas.
- **Laterais são agrupadas.** Cada lateral vira, no grafo, uma sequência de nós com emissores
  agregados (até 100 nós por lateral por padrão, ajustável), o que mantém o cálculo rápido mesmo com
  centenas de emissores por linha.

### Geradores

- **Bloco de laterais** (B): polígono, direção, espaçamento entre laterais, deslocamento da primeira,
  lateral com emissores ou fita, posição do submain (início, centro, fim), válvula (posição e modelo),
  comprimento do pé de válvula (stub), nomes. Se uma linha, polilinha, curva de nível ou spline
  estiver selecionada ao abrir o diálogo, ela pode servir de guia: as laterais seguem a curva
  (paralelas a uma curva de nível ou a uma divisa curva) e são recortadas pelo polígono.
- **Grade de aspersores** (AH): polígono, aspersor e bocal, espaçamentos, padrão quadrado ou
  triangular, direção e pressão de projeto.
- **Envelope de posição do submain** (FE): para cada lateral selecionada, pinta em verde o trecho
  onde o submain pode alimentá-la respeitando a janela de pressão, considerando o terreno.

---

## 7. Catálogo de componentes

O catálogo do projeto tem seis grupos: **tubos**, **emissores** (com bocais), **fitas**, **válvulas
e acessórios**, **bombas** e **conexões**. Todos os valores hidráulicos internos estão em SI.

| Grupo | Campos principais |
|---|---|
| Tubos | DN, diâmetro interno, material, C de Hazen-Williams, rugosidade, classe de pressão, uso (lateral, zona, linha principal), custo por metro, fornecedor, código |
| Emissores e bocais | Tipo (aspersor, microaspersor, gotejador, borbulhador, canhão, ponto de demanda), curva `q = k·H^x`, raio molhado `R = a·H^b`, arco, pressão padrão, mínima e máxima, CV de fabricação, tolerância de vazão, diâmetro de entrada, altura da haste, custo |
| Fitas | Diâmetro interno, espaçamento e curva do emissor, coeficiente de barb, CV, pressão de entrada padrão, mínima e máxima, tolerâncias acima e abaixo, classe, custo por metro |
| Válvulas e acessórios | Tipo (zona, PRV, registro, retenção, anti-refluxo, filtro, hidrômetro, ventosa, outro), diâmetro, perda `h = K·Q^n + C`, vazões mínima e máxima, ajuste padrão da PRV, custo |
| Bombas | Pontos (Q, H) ajustados a uma parábola, eficiência, potência, vazão máxima, custo |
| Conexões | Tipo (luva, cotovelo 90° e 45°, tê, cruzeta, redução, tampão, adaptador, derivação de lateral, final de fita, haste), diâmetros, custo |

O **catálogo padrão** traz 17 tubos (PE 16–50 mm, PVC DN 35–250, PEAD 110 e 160, aço 6"), 9 famílias
de emissores (gotejadores PC e turbulentos, microaspersores, aspersor de impacto, canhão, rotor e
spray de jardim, ponto de demanda), 6 fitas e tubos gotejadores, 30 válvulas e acessórios (1" a 6"),
17 bombas (centrífugas de 1 a 100 cv, submersas de 3 a 25 cv) e cerca de 330 conexões geradas para
cada diâmetro nominal (luvas, cotovelos de 90° e 45°, tês, cruzetas, tampões, adaptadores e reduções, mais conectores de lateral, finais de linha e tubos de subida), com
nomes traduzidos e preços ilustrativos.

O editor (Projeto → Catálogo de componentes) edita, duplica e remove itens, importa e exporta JSON,
CSV por grupo e **Excel** (exporte, preencha preços na planilha e importe de volta), define o
catálogo padrão para novos projetos e restaura o original.

### Catálogos de fabricantes (`.oci.cat`)

Nove pacotes acompanham o app: Netafim, Rivulis, Jain, Toro, Rain Bird, Nelson, Hunter, NaanDanJain
e Senninger, com produtos representativos e dados típicos de catálogo (75 itens). Eles ficam em
[catalogs/](catalogs/) como arquivos JSON, um por fabricante, mais um `index.json`. Pelo diálogo
*Catálogos de fabricantes…* você adiciona um pacote ao projeto, importa um arquivo `.oci.cat` ou
carrega um pacote ou um índice inteiro por URL, o que permite a qualquer revenda ou comunidade manter
o próprio repositório. O catálogo do projeto também é exportado nesse formato. O formato completo,
com os campos de cada grupo e as regras de contribuição, está em [catalogs/README.md](catalogs/README.md);
`dart run tool/gen_catalogs.dart` valida os pacotes (ids únicos, curvas plausíveis) e refaz o índice.

---

## 8. Terreno

- **Fontes de elevação**: curvas de nível desenhadas (com incremento automático e opção de
  suavizar), cotas de ponto (a elevação é pedida a cada clique), pontos de levantamento (CSV, TXT,
  XYZ, PNEZD), DXF/DWG com elevação (polilinhas em camadas de contorno ou com cota), KML com
  altitude, shapefile com Z ou atributo de elevação, GeoTIFF de elevação (raster de uma banda) e a
  **elevação da internet**.
- **Modelo digital**: triangulação de Delaunay (TIN) com interpolação linear nos triângulos,
  exata em rampas planas, e interpolação por inverso da distância como alternativa e como
  complemento fora do casco convexo. As curvas de nível são amostradas a cada 5 m (ajustável).
  Levantamentos com mais de 12 mil pontos são decimados para a triangulação.
- **Elevação da internet** (Projeto → Terreno → Baixar elevação da internet): uma grade de pontos
  sobre o projeto ou sobre a área visível é consultada em serviços públicos e gratuitos, sem chave:
  Open-Meteo (Copernicus GLO-90) e OpenTopoData (SRTM 30 m, ASTER 30 m). Num projeto vazio basta
  colar a coordenada do local (decimal, link do Google Maps ou graus/minutos/segundos): a origem do
  desenho vai para lá e a elevação é baixada num quadrado ao redor. Ao terminar, as curvas de nível
  podem ser geradas automaticamente com intervalo escolhido a partir do desnível.
- **Ferramentas**: gerar curvas de nível do modelo (curvas derivadas, que não realimentam o modelo),
  vista 3D do terreno com os tubos drapejados, perfil ao longo de um caminho (com o tubo e a linha
  piezométrica quando há resultados), e a pressão de cada emissor considera a cota do terreno mais a
  altura da haste menos a profundidade de enterro.

---

## 9. Cálculo e dimensionamento

### Parâmetros de projeto (Projeto → Parâmetros)

| Grupo | Parâmetros e padrões |
|---|---|
| Hidráulica | Fórmula de atrito: Hazen-Williams (padrão) ou Darcy-Weisbach; temperatura da água 20 °C (viscosidade calculada); perdas localizadas 5 % do comprimento, ligadas; escala e deslocamento do C (envelhecimento); tolerância de conexão 0,05 m; máximo de 100 nós agregados por lateral |
| Velocidades máximas | 2,0 m/s em laterais, 1,5 m/s em zona, 2,0 m/s em linha principal |
| Dimensionamento | Método LP (padrão) ou velocidade + janela de pressão (greedy); diâmetros por lateral (1), por submain (3) e por linha principal (3); variação máxima de pressão na zona (0 = derivada da tolerância de vazão do emissor); emissores por planta (1) |
| Economia | Juros 10 %, prazo 10 anos, energia 0,75 por kWh, eficiência da bomba 65 %, 2000 h/ano de linha principal e 500 h/ano por zona, balanço capital × energia ligado, moeda R$ |
| Lavagem e segurança | Velocidade de lavagem das fitas 0,3 m/s com pressão mínima de 1 m na ponta aberta; verificação de golpe de aríete ligada com tempo de fechamento de válvula (0 = instantâneo) |
| Materiais | Seleção automática de conexões ligada; barra de tubo de 6 m para contar luvas |
| Terreno | Interpolação por triangulação (padrão) ou inverso da distância; densificação das curvas 5 m |

### Etapas do cálculo

1. **Construção do grafo**: entidades → nós e trechos; vértices coincidentes fundidos; itens
   pontuais inseridos nos tubos; laterais agregadas; cotas do terreno em cada nó; zonas
   identificadas a partir de cada válvula.
2. **Zonas**, uma a uma:
   - dimensionamento inicial por velocidade máxima, que também fornece as vazões nominais;
   - **LP**: cada trecho dimensionável pode ser composto por frações dos diâmetros candidatos; o
     programa linear minimiza o custo anualizado dos tubos mais o custo de energia da pressão de
     entrada, sujeito à janela de pressão dos emissores críticos (ponta, ponto mais alto e mais
     baixo de cada lateral, cada emissor isolado). Se a análise não confirmar a janela, os emissores
     de pressão mínima e máxima entram como restrições e o LP roda de novo (até quatro rodadas);
   - **reparo**: aumento guloso de diâmetro ao longo do caminho crítico até a janela ser atendida;
   - **racionalização**: diâmetros decrescentes de montante para jusante e telescopagem dentro do
     limite de diâmetros por unidade;
   - **análise detalhada**: rede não linear com emissores dependentes da pressão; a pressão a
     jusante da válvula é escolhida por bissecção para que a pressão média dos emissores seja a
     nominal (ou, para fitas reguladas, para garantir a pressão mínima de submain);
   - resultados: vazão da zona, pressões mínima e máxima e admissíveis, variação admissível e real,
     pressão requerida na válvula, perda na válvula, uniformidade (CU de Christiansen, DU do quartil
     inferior, EU de Keller-Karmeli com o CV do fabricante e emissores por planta, uniformidade
     estatística, variação de vazão), CU de sobreposição para aspersores com raio molhado, tabela de
     tubos com pressões, cotas e velocidades, tabela de emissores.
3. **Linha principal**, por turno: demanda e pressão requerida de cada válvula e pivô, LP sobre
   todos os turnos com custo de energia ponderado pelas horas de cada um, análise de cada turno com
   bombas (ponto de operação), PRVs, válvulas de retenção e fontes de pressão fixa ou calculada;
   duty de cada fonte (vazão, pressão disponível, requerida, déficit) e energia anual.
4. **Telescopagem**: tubos com mais de um diâmetro são divididos em entidades, maior diâmetro a
   montante, e as zonas afetadas são reanalisadas.
5. **Lavagem**: cada zona com fitas é analisada com as pontas abertas na velocidade de lavagem;
   reporta vazão de lavagem, pressão necessária na válvula e a montante, número de fitas, pressão
   mínima na ponta e velocidade máxima.
6. **Golpe de aríete**: para o pior trecho de cada tubo, celeridade da onda pelo material e parede,
   sobrepressão de Joukowsky para a velocidade de operação, tempo crítico 2L/a e comparação da
   pressão estática máxima mais sobrepressão com a classe do tubo, considerando o tempo de fechamento.
7. **Materiais**: tubos por diâmetro e classe, emissores, fitas, válvulas, acessórios, bombas
   (com seleção automática a partir do catálogo e motor padrão IEC), pivôs com torres, aspersores e
   reguladores, e **conexões selecionadas automaticamente** da geometria (luvas por barra, cotovelos,
   tês, cruzetas, reduções, tampões, derivações de lateral, finais de fita, hastes), com custos e
   custo anualizado (fator de recuperação de capital) mais energia.

O cálculo roda num **Web Worker** no navegador (ou num isolate no desktop) e devolve à interface as
entidades redimensionadas e os resultados; enquanto ele roda, a edição é bloqueada para não perder
alterações, mas navegação, relatórios e outras abas seguem livres.

### Verificação de projeto

| Código | Gravidade | Significado |
|---|---|---|
| `unconnected` | erro | Item hidráulico sem ligação com a rede |
| `no_supply` | erro | Nenhuma fonte de água |
| `no_valves` | erro | Nenhuma válvula de zona (nem pivô) |
| `zone_no_emitters` | erro | Válvula sem emissores a jusante |
| `spec_missing` | erro | Item referencia um componente que não está no catálogo |
| `zero_length` | erro | Tubo de comprimento nulo |
| `pivot_unconnected` | erro | Pivô fora de um nó da linha principal |
| `pipes_cross` | aviso | Tubos que se cruzam sem junção |
| `mainline_dead_end` | aviso | Ponta solta na linha principal |
| `duplicate_item`, `duplicate_zone_name` | aviso | Itens sobrepostos; zonas com o mesmo nome |
| `tiny_segment` | aviso | Segmento menor que a tolerância |
| `supply_no_head` | aviso | Fonte de pressão fixa sem pressão informada |
| `zone_dead_end`, `area_no_emitters`, `no_terrain`, `looped_mainline`, `no_hydraulics` | informação | Situações que merecem atenção mas não impedem o cálculo |

### Mensagens do cálculo

Cada zona, turno e etapa pode emitir avisos, mostrados na aba Mensagens e junto ao item: pressão
fora da janela, velocidade excedida, classe de pressão excedida (em operação ou por golpe de aríete),
válvula fora da faixa de vazão, bomba fora da curva, fonte com vazão ou pressão excedida, déficit de
pressão na válvula ou no pivô, LP inviável (com o método guloso assumindo), linha principal em anel
(o LP usa caminhos em árvore como aproximação e a análise final confere), componentes de catálogo
ausentes, taxa de aplicação do pivô acima do limite do solo, entre outras.

### Calculadoras (menu Ferramentas)

- **Lateral**: comprimento máximo, perdas e uniformidade de uma lateral ou fita em declive.
- **Bomba e curva do sistema**: ponto de operação, potência e energia anual.
- **Golpe de aríete**: sobrepressão de Joukowsky contra a classe do tubo.

---

## 10. Relatórios, plotagem e exportação

### Painel de relatórios

Abas: resumo das zonas, tubos, emissores, linha principal e duty, lista de materiais, requisitos
hídricos, agronomia (ETc, água prontamente disponível, intervalo, lâminas, horas por evento),
programação (calendário do controlador por turno), lavagem, golpe de aríete, pivôs e vãos do pivô,
linha piezométrica (gráfico do tubo, lateral ou válvula selecionada, com a banda de pressão
admissível), perfil (terreno ao longo de um caminho, com tubo e linha piezométrica) e mensagens.
As tabelas são virtualizadas, com colunas medidas pelo conteúdo, e servem de base para todos os
exportadores, de modo que PDF, Excel e CSV mostram os mesmos números.

### Prancha em PDF

Arquivo → Exportar desenho → PDF abre as opções de plotagem: tamanho (A4 a A0, Letter, Tabloid),
orientação, escala (automática ou fixa), margem, raios molhados, rótulos, legenda de camadas, lista
de materiais na folha e páginas de relatório anexadas. A cena é montada em "espaço do papel": pena,
símbolos e textos em milímetros de papel, para que 1:500 e 1:2000 fiquem igualmente legíveis. O
carimbo traz os detalhes do projeto, a seta norte e a escala gráfica. O escritor PDF é próprio
(PDF 1.4, fontes Helvetica, compressão Flate), sem dependências.

### Exportações

| Formato | Conteúdo | Observações |
|---|---|---|
| DXF | Entidades por camada, R12 | Abre em qualquer CAD |
| DWG | AutoCAD 2000 (AC1015) | Escritor próprio, validado com LibreDWG e relido pelo leitor do app |
| PDF | Prancha com carimbo, legenda, seta norte, escala e, opcionalmente, relatórios | |
| SVG | Folha em milímetros, um grupo por camada | Navegadores, Inkscape |
| KML / KMZ | Pastas por camada, coordenadas WGS84 | Google Earth; exige georreferência |
| GeoJSON | FeatureCollection com atributos | QGIS, web GIS; exige georreferência |
| CSV, TXT, XLSX, PDF | Relatórios (todas as tabelas) | XLSX com uma planilha por tabela e números como números |
| CSV do controlador | Programa de irrigação: eventos por turno, dias e horários | Gerenciamento → Exportar |

---

## 11. Formatos de arquivo

### Projeto (`.oci.json`)

JSON legível com estas chaves de primeiro nível:

| Chave | Conteúdo |
|---|---|
| `format`, `version` | `"opencadirrigation"`, `1` (o nome antigo `irrigationcad` ainda é aceito) |
| `meta` | uid estável, datas de criação e modificação, nome, cliente, obra, projetista, notas, georreferência (fuso UTM, hemisfério, origem E/N) |
| `params` | Todos os parâmetros de projeto e as unidades |
| `catalog` | O catálogo do projeto completo (o arquivo é autossuficiente) |
| `layers` | Nome, cor ARGB, visível, bloqueada |
| `entities` | Uma entrada por entidade, com `type`, `id`, `layer`, `name` e os campos próprios (pontos em metros) |
| `systemFlows` | Turnos: nome, válvulas, hora de início, duração |
| `nextId`, `currentLayer` | Contador de ids e camada corrente |
| `results` | Opcional: resultados do último cálculo, para reabrir com relatórios sem recalcular |

O mesmo JSON é usado pelo autosave, pelas versões, pela área de transferência entre projetos e pelo
worker de cálculo.

### Importação

| Formato | O que entra | Detalhes |
|---|---|---|
| DXF (ASCII) | LINE, LWPOLYLINE e POLYLINE (com arcos de bulge), CIRCLE, ARC, ELLIPSE, SPLINE, TEXT, MTEXT, ATTRIB, POINT, camadas e blocos (INSERT, MINSERT e o bloco das cotas DIMENSION, inclusive aninhados) | R12 a 2018, Latin-1 ou UTF-8; polilinhas com elevação (2D ou vértices 3D) viram curvas de nível; pontos com Z viram cotas; escala pelas unidades do arquivo |
| DWG | Mesmas entidades, camadas, blocos (INSERT, MINSERT) e cotas | R13/R14 (parcial), 2000, 2004, 2007, 2010, 2013 e 2018, em Dart puro; avisa objetos ignorados |
| KML / KMZ | Placemarks, pastas como camadas, altitude ou atributo ELEV como elevação | WGS84 → UTM (fuso automático) com origem local; georreferencia o projeto |
| SHP (+ DBF, PRJ, CPG em zip) | Pontos, linhas, polígonos, multipontos, variantes Z | Elevação do Z ou de atributo ELEV/Z/COTA; nome de NAME/NOME/ID; atributos em UTF-8 ou Latin-1 (.cpg); sem .prj, graus são reconhecidos pela faixa e pela precisão |
| CSV, TXT, XYZ, PNEZD | Pontos de levantamento | Colunas detectadas pelo cabeçalho ou posição; vírgula decimal aceita; lat/lon reconhecidos |
| GeoTIFF de elevação | Grade de cotas | Uma banda de alturas, float ou inteiro, nodata ignorado |
| JPG, PNG, GeoTIFF, zip com world file | Imagem de fundo | Georreferenciada (world file, inclusive rotacionado; tags GeoTIFF) ou colocada à mão e alinhada por 2 pontos |

### Catálogos e exemplos

Pacotes `.oci.cat` em [catalogs/](catalogs/) (formato em [catalogs/README.md](catalogs/README.md)) e
projetos de exemplo em [examples/](examples/), regenerados por ferramentas e guardados por testes.

---

## 12. Armazenamento, privacidade e rede

- **Autosave** no armazenamento do navegador, no máximo a cada 3 segundos de atividade e ao fechar
  uma aba; **projetos recentes** (os 8 últimos) em Arquivo → Recentes; **versões** (as 10 últimas
  gravações de cada projeto) em Arquivo → Versões; **recuperação** ao abrir o app quando há autosaves
  não salvos. O limite por projeto é de cerca de 3,5 MB (imagens embutidas são descartadas do
  autosave quando estouram o limite). Um aviso do navegador aparece ao fechar a aba com alterações.
- **Arquivos**: Salvar gera `.oci.json` para download; Abrir lê do disco. Nada é enviado a servidores.
- **Acesso à internet**, só quando você pede: elevação online (Open-Meteo, OpenTopoData), mapas base
  (OpenStreetMap, OpenTopoMap, CARTO, Esri, Google Maps com a sua própria chave ou uma URL XYZ
  personalizada) e catálogos carregados por URL. A chave do Google Maps fica só no navegador e é
  enviada apenas ao Google; onde o servidor não tem imagem no zoom atual, o app amplia o tile mais
  próximo em vez de mostrar um aviso de "dados indisponíveis".
- **Idioma e preferências** (idioma escolhido, catálogo padrão, tutorial concluído) ficam nas
  preferências do navegador.

---

## 13. Idiomas e site

A interface está em **20 idiomas**, os mais falados do mundo. Português, inglês e espanhol vêm
compilados no app; chinês (`zh`), hindi (`hi`), árabe (`ar`), francês (`fr`), bengali (`bn`), russo
(`ru`), urdu (`ur`), indonésio (`id`), alemão (`de`), japonês (`ja`), marati (`mr`), vietnamita
(`vi`), télugo (`te`), hauçá (`ha`), turco (`tr`), panjabi (`pa`, escrita gurmukhi) e suaíli (`sw`)
são pacotes de idioma em `assets/i18n/<código>.json`, baixados só quando o idioma é escolhido (a
interface mostra inglês até o pacote chegar, uma fração de segundo). Cada pacote traduz toda a tabela
de textos, o tutorial interativo e os nomes do catálogo padrão; o worker de projeto recebe o pacote
junto com o pedido, então relatórios e plotagens também saem no idioma escolhido. O app abre no
primeiro idioma da lista de idiomas preferidos do sistema (do navegador ou do sistema operacional)
que ele fala, e em inglês quando nenhum deles é falado; a troca em Ver → Idioma (cada idioma com o
próprio nome) fica salva. As páginas `/en/` e `/es/` e o parâmetro `?lang=` valem só para a visita.
O atributo `lang` do documento acompanha o idioma do app (`pt-BR`, `zh-CN`, senão o código). Os
textos em árabe e urdu são escritos da direita para a esquerda; o layout da interface continua da
esquerda para a direita. Os projetos de exemplo distribuídos mantêm os rótulos em português, inglês
e espanhol.

Um pacote é um JSON simples com três seções: `strings` (chave → texto), `tutorial` e `catalog`
(texto de origem em inglês → texto). Tradutores podem revisá-lo sem tocar no código;
`test/core/i18n_packs_test.dart` verifica que cada pacote cobre todas as chaves com os mesmos
marcadores.

O site é gerado por `dart run tool/gen_site.dart` a partir de `tool/site.dart`: `web/index.html`
(pt-BR), `web/en/index.html`, `web/es/index.html`, `web/sitemap.xml` e `web/404.html`. Como o
Flutter desenha em canvas, cada página traz o conteúdo em HTML real (título, recursos, exemplos,
perguntas frequentes), visível enquanto o app carrega e mantido na página depois, com canônica
própria, `hreflang` entre as três versões, Open Graph e JSON-LD. O teste `test/web_metadata_test.dart`
falha quando os arquivos gerados divergem do template.

---

## 14. Arquitetura do código

```
lib/
  core/                     Dart puro, sem Flutter (roda no worker, no isolate e nas ferramentas)
    hydraulics/             fórmulas e solvers
      friction.dart           Hazen-Williams, Darcy-Weisbach (Swamee-Jain, Colebrook, Blasius, laminar, transição)
      minor_losses.dart       K de acessórios, comprimento equivalente, curva h = K·Q^n + C
      emitter.dart            q = k·H^x, raio molhado, janela de pressão, taxa de aplicação, CU de sobreposição
      lateral.dart            análise passo a passo de laterais, comprimento máximo, posições de alimentação
      network.dart            solver de rede (Global Gradient Algorithm) com emissores, bombas, PRV, retenção
      sparse_solver.dart      LDLᵀ esparso com ordenação por grau mínimo
      pump.dart               curvas de bomba e do sistema, ponto de operação, potência, CRF, energia
      uniformity.dart         CU, DU, EU, Us, variação de vazão
      water_hammer.dart       celeridade, Joukowsky, tempo crítico
    model/                  dados
      geometry.dart           Pt, Bounds, segmentos, polígonos, offsets, transformações afins
      entities.dart           entidades de desenho e hidráulicas (JSON, clone, transformar, grips, distância)
      catalog.dart            catálogo de componentes e base padrão
      catalog_packs.dart      pacotes de fabricantes (em memória) e fusão
      project.dart            projeto: meta, parâmetros, catálogo, camadas, entidades, turnos
      terrain.dart, tin.dart  modelo do terreno: TIN de Delaunay, IDW, curvas de nível
      spatial_index.dart      R-tree STR para culling, seleção e snap
      split.dart              divisão de entidades lineares
    design/                 projetista
      network_builder.dart    entidades → grafo hidráulico (nós, trechos, zonas, agregação de emissores)
      designer.dart           orquestração: zonas, linha principal, telescopagem, lavagem, golpe de aríete, BOM
      lp.dart, lp_sizing.dart simplex denso de duas fases e formulação do dimensionamento
      block_generator.dart    blocos de laterais (retos e guiados) e grades de aspersores
      pivot.dart              hidráulica de pivô central e linear
      fittings.dart           seleção automática de conexões
      pump_selection.dart     escolha de bomba e motor
      agronomy.dart           ETc, balanço hídrico, programa do controlador
      design_check.dart       verificação de projeto
      results.dart, report_tables.dart  resultados serializáveis e tabelas dos relatórios
    io/                     leitura e escrita de formatos
      dxf.dart, dwg.dart, dwg_writer.dart, kml.dart, shp.dart, points_csv.dart,
      geoimage.dart, dem_tiff.dart, dem_online.dart, geo.dart, geo_export.dart,
      plot.dart, pdf.dart, pdf_sheet.dart, svg.dart, xlsx.dart, catalog_io.dart, project_export.dart
    units.dart              unidades (métrico/US), viscosidade da água
    translate.dart          gancho de tradução para relatórios e plotagens rotularem a saída sem Flutter
    i18n/language_packs.dart registro dos pacotes de idioma (textos, tutorial, nomes do catálogo)
  app/                      Flutter
    state/                  ProjectController (projeto, seleção, câmera, undo, índice espacial, cálculo),
                            Workspace (abas e área de transferência), DesignRunner (worker/isolate/thread)
    canvas/                 CadCanvas, CadPainter, Camera, Snapper, mapa base
    tools/                  ferramentas de desenho, edição e hidráulica
    keys/                   despachador de atalhos e listener nativo
    widgets/                menus, paleta, painéis, relatórios, gráficos, diálogos, layout compacto
    tutorial/               tutorial interativo
    io/                     arquivos, preferências, HTTP, armazenamento local, documento HTML, links externos
    actions.dart            ações de arquivo, área de transferência e exportação compartilhadas por menus, paleta e atalhos
    examples.dart           galeria de exemplos
    i18n.dart               tabela de textos pt/en/es, lista de idiomas e carregamento sob demanda dos pacotes
    i18n_assets.dart        lê assets/i18n/<código>.json para o idioma escolhido
    shortcuts.dart          aliases de comando (pt/en/es) e tabela de atalhos
    theme.dart              tema Material escuro do app
    version.dart            versão do app gerada (tool/gen_version.dart)
  worker/design_worker.dart entrada do Web Worker
catalogs/                   pacotes de fabricantes (JSON) e índice
examples/                   projetos de exemplo em pt, en, es
tool/                       geradores: site, catálogos, exemplos, marca, versão; builds do worker e da web
test/                       testes do motor, do modelo, dos formatos e da interface
web/                        páginas, manifest, ícones, robots, sitemap, worker compilado
```

### Decisões de projeto

- **Motor em Dart puro.** `lib/core` não importa Flutter, por isso roda no Web Worker, no isolate,
  em `dart run` (ferramentas) e em testes rápidos. A interface só monta requisições e mostra resultados.
- **Um controller por projeto.** `ProjectController` guarda o projeto, a seleção, a câmera, a pilha
  de desfazer (snapshots das entidades), o índice espacial e o estado do cálculo. Toda edição passa
  por `mutate`, que tira o snapshot, marca o projeto como sujo, invalida resultados e o índice,
  notifica a interface e agenda o autosave.
- **Cálculo fora da thread.** O projeto vai serializado ao worker; o worker devolve resultados e as
  entidades redimensionadas; um contador de edições descarta resultados de um projeto que mudou
  enquanto calculava.
- **Índice espacial.** R-tree empacotada por STR reconstruída a cada edição; a pintura consulta só a
  janela visível e seleção, snap e janela de seleção consultam o índice (consulta em microssegundos
  com dezenas de milhares de entidades).
- **Formatos próprios em Dart puro.** Leitores e escritores de DWG, PDF, XLSX, SHP, GeoTIFF etc. não
  dependem de bibliotecas nativas, o que mantém o app 100 % web.
- **Textos centralizados.** Todas as strings da interface estão em `i18n.dart` como tuplas
  (pt, en, es); o motor devolve códigos (`velocity_exceeded:e12`) que a interface traduz.

---

## 15. Desenvolvimento

Requisitos: Flutter estável recente (desenvolvido com 3.47, Dart 3.13). Sem dependências nativas.

```bash
flutter pub get
flutter run -d chrome              # desenvolvimento no navegador
flutter test                       # 350 testes: motor, modelo, formatos, interface
flutter analyze                    # lints
tool/build_worker.sh               # recompila web/design_worker.js após mudar lib/core (o app cai
                                   # para a thread da interface quando o arquivo não existe)
tool/build_web.sh                  # build de publicação: worker + flutter build web com o commit git e a data
                                   # gravados na versão (boas-vindas, barra de status, Ajuda → Sobre, console)
flutter build web --release        # o mesmo sem commit/data (build/web, pronto para hospedagem estática; web/CNAME guarda o domínio)
dart run tool/gen_version.dart     # regenera lib/app/version.dart após mudar `version:` no pubspec.yaml
dart run tool/gen_site.dart        # páginas do site (index pt-BR, /en/, /es/, sitemap, 404)
dart run tool/gen_catalogs.dart    # valida e normaliza catalogs/*.oci.cat e refaz index.json
dart run tool/gen_examples.dart    # regenera examples/<lang>/*.oci.json a partir de lib/app/examples.dart
dart run tool/gen_brand.dart       # ícones e ativos de marca a partir de web/brand
python3 tool/formats/make_fixtures.py   # regrava test/fixtures/formats com ezdxf, pyshp, tifffile, Pillow, openpyxl e LibreDWG
python3 tool/formats/check_exports.py   # valida build/formats (escrito por flutter test) com leitores independentes
```

Os geradores têm testes de guarda: quando um arquivo gerado diverge da fonte, o teste
correspondente falha com a instrução de qual comando rodar. Builds para desktop
(`flutter run -d macos|windows|linux`) usam o isolate para o cálculo.

### Como estender

- **Nova entidade**: classe em `entities.dart` (JSON, clone, transformar, grips, distância, bounds),
  `EntityType`, camada padrão, pintura em `painter.dart`, propriedades em `properties_panel.dart`,
  ferramenta em `tools.dart` e alias em `shortcuts.dart`, exportação em `plot.dart`/`dxf.dart`.
- **Novo relatório**: tabela em `report_tables.dart` (os exportadores CSV/TXT/XLSX/PDF e o painel a
  recebem automaticamente) e textos em `i18n.dart`.
- **Novo formato**: leitor ou escritor em `lib/core/io`, entrada em `importFile` do controller ou em
  `DrawingFormat`/`ReportFormat`, e um teste de ida e volta.
- **Nova fórmula**: em `lib/core/hydraulics`, com um teste contra um valor de referência.

---

## 16. Testes

`flutter test` roda 350 testes em cerca de um minuto e meio. O que cada grupo garante:

| Arquivo | Cobertura |
|---|---|
| `core/hydraulics_test.dart` | Hazen-Williams contra valor de livro-texto; Darcy-Weisbach ≈ Hazen-Williams em PVC liso; fator laminar; Swamee-Jain ≈ Colebrook; continuidade na transição; tabela do fator F de Christiansen e ajuste de Scaloppi; diâmetro equivalente; lei do emissor e ajuste; taxa de aplicação; CU de sobreposição; CU/DU/EU; ajuste de curva de bomba, ponto de operação, CRF; K → forma de vazão; celeridade em PVC |
| `core/network_test.dart` | Solver esparso; tubo simples; anéis; conservação de massa; emissores dependentes da pressão; bomba; PRV; curva de acessório; convergência em Darcy-Weisbach; rede ramificada grande rápida; comparação com Christiansen; laterais em declive; comprimento máximo; posições de alimentação |
| `core/lp_test.dart` | Simplex: ≤/≥, igualdades, inviável, ilimitado, problema com a forma do dimensionamento |
| `core/design_test.dart`, `core/sizing_features_test.dart`, `core/gaps_test.dart` | Gerador de blocos; grafo conectado; análise e dimensionamento completos; LP não pior que o guloso; telescopagem; conexões; lavagem; golpe de aríete; CU de sobreposição e emissores por planta; agronomia e programa do controlador; seleção de bomba e motor; DEM GeoTIFF; pivô (vãos, custos); linha principal em anel |
| `core/terrain_pivot_test.dart` | TIN de Delaunay exato em planos; TIN vs IDW; geração de curvas; encadeamento de segmentos; geometria de alinhamento e recorte; blocos guiados; hidráulica de pivô; verificação de projeto; catálogo Excel e pacotes |
| `core/dwg_test.dart`, `core/dwg_writer_test.dart` | Leitura de amostras R2000–R2018 e R2007, com blocos e cotas expandidos; rejeição de versões desconhecidas; CRC; ida e volta do escritor; validação com LibreDWG quando instalado |
| `core/formats_test.dart` | Cada formato de importação contra arquivos gravados por outros programas (ezdxf, LibreDWG, pyshp, tifffile, Pillow, openpyxl e KML no estilo do Google Earth; fixtures em `test/fixtures/formats`, gerados por `tool/formats/make_fixtures.py`) com posições, elevações, nomes e camadas conferidos; todas as exportações relidas pelos próprios leitores e gravadas em `build/formats` para `tool/formats/check_exports.py`, que as valida com ezdxf, LibreDWG, lxml, openpyxl e pypdf |
| `core/export_test.dart`, `core/kml_test.dart` | UTM ida e volta; georreferência; KML ida e volta; GeoJSON; cena de plotagem; SVG; PDF válido e comprimido; prancha e páginas de relatório; mesmas tabelas em CSV/TXT/XLSX |
| `core/catalog_packs_test.dart` | Todos os pacotes em `catalogs/` carregam, ids únicos sem colidir com o catálogo padrão, arquivos normalizados e índice coerente; formato do pacote; carregadores (assets e URL) |
| `core/examples_test.dart` | Cada exemplo, nos 20 idiomas, constrói, é conectado, passa na verificação, projeta com zonas dentro da janela e sem déficit, e bate com os arquivos em `examples/` |
| `core/spatial_index_test.dart` | Índice contra força bruta, ordem de desenho, casos degenerados, invalidação no controller, seleção e snap |
| `core/geo_parse_test.dart`, `core/i18n_lang_test.dart` | Coordenadas coladas (decimais, vírgula, hemisférios, DMS, links); intervalo de curvas; escolha de idioma pelo sistema e pela URL |
| `core/i18n_packs_test.dart` | Cada pacote de idioma cobre todas as chaves da tabela, do tutorial e dos nomes do catálogo com os mesmos marcadores e não é majoritariamente inglês; pacotes instalados chegam aos textos, ao tutorial e ao catálogo; `setLanguage` carrega o pacote sob demanda com inglês enquanto isso e repete um carregamento que falhou |
| `core/editing_test.dart`, `core/model_test.dart`, `core/workspace_test.dart`, `core/design_job_test.dart`, `core/app_io_test.dart`, `core/entities_roundtrip_test.dart` | Edição (grips, transformações, aparar, estender, cortar), JSON das entidades, abas e área de transferência, protocolo do worker, HTTP local, armazenamento de projetos, câmera e snap |
| `widget_*.dart` | Interface real: tela inicial e tutorial, galeria, menus e diálogos, painéis, edição no canvas, atalhos, histórico, terreno e layout compacto |
| `web_metadata_test.dart` | Páginas do site geradas, SEO, manifest, ícones, robots, sitemap, 404 |

Armadilhas conhecidas ao escrever testes de widget: o cálculo é assíncrono de verdade e deve rodar
dentro de `tester.runAsync`; títulos de diálogo podem estar em maiúsculas; o canvas precisa de um
tamanho de janela definido; o carregamento de assets (catálogos) usa `rootBundle` e funciona em
`flutter test`.

---

## 17. Limitações conhecidas e roteiro

- **Redes malhadas**: o LP dimensiona malhas por caminhos em árvore (aproximação) e a análise final
  confere; o método guloso é a alternativa segura.
- **DWG**: o leitor cobre as entidades típicas de uma planta (linhas, polilinhas, círculos, arcos,
  pontos, textos, blocos e cotas); splines e hachuras do DWG não são importadas; o escritor grava
  apenas AutoCAD 2000, com linhas, polilinhas, círculos, arcos, pontos e textos.
- **Cálculo em regime permanente**: golpe de aríete é uma estimativa de Joukowsky, não um transiente
  completo; não há fertirrigação, sistema elétrico nem controladores além do programa de irrigação.
- **Pivôs**: hidráulica da máquina e demanda sobre a linha principal, sem projeto de bocais por
  posição além da tabela de vãos.
- **Colaboração**: não há edição simultânea nem compartilhamento por link; o compartilhamento é pelo
  arquivo `.oci.json`.
- **Desempenho**: projetos com centenas de fitas por zona levam alguns segundos por zona; a etapa de
  lavagem é a mais pesada.

Roteiro sugerido: splines e hachuras no DWG; exportação de planilhas de bocais de pivô; catálogos
adicionais da comunidade; testes de navegador automatizados para a troca de idioma em tempo de
execução.

---

## 18. Contribuindo

- **Catálogos**: siga [catalogs/README.md](catalogs/README.md), rode `dart run tool/gen_catalogs.dart`
  e abra um pull request; os testes garantem ids únicos e curvas plausíveis.
- **Exemplos**: adicione um construtor em `lib/app/examples.dart`, textos em `i18n.dart` e rode
  `dart run tool/gen_examples.dart`; o teste projeta o exemplo e exige zonas dentro da janela.
- **Traduções**: cada chave de `i18n.dart` é uma tupla (pt, en, es); as páginas do site ficam em
  `tool/site.dart`. A documentação é mantida em inglês (`README.md`, `docs/TECHNICAL_STUDY.md`) e
  traduzida para o português (`README.pt-BR.md`, `docs/PESQUISA.pt-BR.md`): altere primeiro a versão em inglês.
- **Motor**: toda fórmula nova vem com um teste contra um valor de referência publicado.
- **Regra editorial**: este repositório não cita empresas nem produtos de software de terceiros, nem
  de forma indireta; fabricantes de componentes aparecem apenas como origem dos dados de catálogo,
  e formatos de arquivo de terceiros apenas pelo nome do formato.

---

## 19. Referências

O estudo que orientou o projeto, com o que um projetista espera de um CAD de irrigação, as fórmulas
do motor, as formulações de dimensionamento, agronomia, pivôs, terreno, os formatos de arquivo e a
bibliografia, está em [docs/PESQUISA.pt-BR.md](docs/PESQUISA.pt-BR.md).
