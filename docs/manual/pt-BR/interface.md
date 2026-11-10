# Interface

## Layout (tela larga)

- **Barra de menus** no topo (os menus que não cabem numa janela estreita vão para ⋯); à direita, os
  botões ▶ Projetar e Salvar (âmbar quando há alterações).
- **Abas de projeto** logo abaixo: vários projetos abertos ao mesmo tempo (Ctrl+Alt+N nova aba,
  Ctrl+Alt+W fecha, Ctrl+Alt+←/→ alterna). Copiar e colar (Ctrl+C/X/V) funciona entre abas e
  entre janelas do navegador, levando camadas e itens de catálogo que faltem no destino (um item
  cujo id o destino dá a outra coisa é renomeado, os preços seguem a moeda do destino, e entre
  projetos georreferenciados os itens mantêm o seu lugar no mapa).
- **Paleta de ferramentas** à esquerda, por grupos (navegação, desenho, edição, terreno, zona,
  linha principal, elétrica, revisão).
- **Canvas** ao centro, com grade, snaps, sobreposições e cartão de progresso do cálculo.
- **Painel lateral** à direita com três abas: **Propriedades** do item selecionado (com resultados
  hidráulicos após o cálculo e o envelope de posição da linha de derivação para laterais; uma
  seleção de vários tipos mostra uma ficha por tipo, para editar um tipo por vez), **Camadas**
  (visibilidade, bloqueio, cor, renomear, criar, remover, isolar e estados de camadas) e
  **Histórico** (linha do tempo de estados, como no Photoshop: clique para voltar ou avançar).
  Arraste a borda dele para mudar a largura, que fica guardada; Ver → Interface o recolhe.
- **Relatórios** embaixo do canvas (F2), redimensionável.
- **Painel do assistente de IA** (opcional, [assistente de IA](ai-assistant.md)) encaixado ao lado
  do canvas, aberto e fechado por Projeto → Assistente de IA… ou pelo botão dele na barra de status.
- **Barra de status** com coordenadas do cursor, snap ativo (e o snap escolhido só para o próximo
  ponto), comando ou coordenadas digitadas, dica da ferramenta, interruptores (snap, orto, grade,
  rastreamento polar, manter conexões), a escala real da tela, a precisão do GPS enquanto o GPS do
  aparelho está ligado, o indicador de análise automática, um aviso enquanto a cópia no navegador
  não pode ser guardada, o botão do assistente de IA e a versão do app.
- **Paleta de comandos** (Ctrl+K, Ajuda → Pesquisar comandos…): todo item dos menus, os comandos
  digitados e os interruptores da tela e da interface, procurados pelo nome no idioma da interface
  ou em inglês, sem acento nem caixa; ↑ ↓ escolhem, Enter executa. No celular a busca fica no topo
  do menu ☰.
- **Ajuda → Manual (F1)** e o **?** das principais janelas e painéis: uma explicação curta de cada
  parte do programa no idioma da interface, com o seu capítulo deste manual a um clique. Ajuda →
  Novidades lista as novidades da versão (também uma vez depois de uma atualização), Ajuda →
  Mensagens recentes… guarda os avisos mostrados na tela, e Ajuda → Relatar problema ou sugerir
  função… prepara uma issue do GitHub com um diagnóstico sem dados pessoais, ou copia o texto.

Em árabe e urdu todo o layout é espelhado (menus, painéis e diálogos da direita para a esquerda);
o desenho mantém as suas coordenadas.

**Interface**: Ver → Interface ajusta o tamanho de toda a interface (sem mexer no zoom do
navegador), o alto contraste (paletas escura e clara a 7:1), o modo foco (só a prancheta,
Ctrl+Alt+F) e o painel lateral recolhido.

Os **números** aparecem no formato do idioma da interface: vírgula decimal na tela em português,
espanhol, alemão, francês, indonésio, turco, russo e vietnamita, e um número digitado como "2.000" em
português é dois mil; quando um número digitado admite as duas leituras, o campo oferece a outra
logo abaixo. Arquivos, exportações técnicas e o assistente de IA continuam com ponto decimal.

**Tema**: Ver → Tema → Escuro (o padrão), Claro ou Seguir o sistema (também no menu do celular). A
escolha fica salva e troca na hora, sem perder os projetos abertos, a seleção nem os diálogos
abertos. No canvas claro (branco) as cores do desenho seguem a regra usual dos CADs: branco e
quase branco são desenhados quase pretos e as demais cores claras são escurecidas mantendo o
matiz, para que nada desapareça no fundo; os dados mantêm as suas cores, e a seleção aparece em
magenta em vez de amarelo. Plotagens e exportações (pranchas em PDF, SVG, PNG) são papel e não
mudam com o tema.

## Layout compacto (celular e tablet)

Abaixo de 700 px de largura, e no celular deitado, a tela muda: menu ☰ no topo (com uma busca, as
abas e os projetos recentes), barra de ferramentas por grupos embaixo, botões Concluir/Cancelar no
lugar de Enter/Esc, propriedades, relatórios e o assistente de IA em painéis deslizantes. Pinça para
zoom, dois dedos para mover, um dedo desenha; o botão ⌨ digita comandos, coordenadas e comprimentos
(com as teclas @ < , ; - . e ABC/123). Um dedo parado abre o menu de contexto da prancheta, e parado e
depois arrastado abre uma janela de seleção; *Somar à seleção* faz cada toque valer como
Shift+clique; uma lupa sobre o dedo mostra onde vai o ponto, posto onde o dedo sobe. Entre 700 e
1100 px (um tablet em retrato, uma janela estreita) o painel lateral vai para uma gaveta e o
assistente de IA para uma folha. Os botões têm pelo menos 48 px para o dedo.

## Menus

| Menu | Itens |
|---|---|
| Arquivo | Novo projeto, Nova aba de projeto, Fechar aba, Abrir projeto, Projetos recentes ▸ (e Armazenamento do navegador), Salvar projeto, Histórico de versões, Salvar automaticamente no navegador (liga/desliga), Exemplos ▸, Importar (DXF, DWG, DGN, PDF, KML/KMZ, SHP, GeoJSON, GPX, LandXML, LAS, EPANET, pontos CSV/TXT/XYZ/PTS/PNEZD, imagens, GeoTIFF), Inserir projeto, Georreferenciar imagem selecionada, Alinhar por 2 pontos, Exportar desenho ▸ (DXF, DXF R12, DWG, PDF, SVG, KML, KMZ, GeoJSON, Shapefile, GPX, LandXML, IFC 4, EPANET, PNG, pontos para locação), Exportar relatório ▸ (CSV, TXT, XLSX, PDF, programação do controlador), Exportar pacote de documentos (PDF), Compartilhar por link, Detalhes do projeto, Carimbo e responsável técnico, Georreferência, Salvar como, Salvar como cópia, Armazenamento do navegador, Comparar com, Trazer comentários de uma cópia, Dados baixados guardados |
| Editar | Desfazer, Refazer, Selecionar tudo, Copiar, Recortar, Colar, Duplicar seleção, Excluir seleção, Materiais da seleção, Salvar seleção como bloco, Inserir bloco, Modificar ▸ (rotacionar, espelhar, escalar, deslocar, aparar, estender, cortar tubo, alinhar por 2 pontos, matriz), Mover, Copiar com ponto-base, Selecionar ▸ (semelhantes, seleção rápida, tudo na camada atual, laço, cerca), Geometria ▸ (esticar, concordância, chanfro, quebrar em dois pontos, unir, explodir, converter em área, subtrair da área, remover as ilhas da área), Alongar, Contorno por clique interno, Ordem de desenho ▸ (trazer para a frente, mandar para trás), Mover para a camada atual, Blocos ▸ (editar bloco no lugar, explodir referências, exportar e importar a biblioteca de blocos) |
| Ver | Enquadrar tudo, Aproximar/Afastar, Grade, Rótulos, Raios molhados, Alças de edição, Rótulos condicionais, GPS do aparelho, Sobreposição (nenhuma, velocidade, pressão, diâmetros, pressão mín/máx por zona, densograma, declividade do terreno, exposição do terreno), Mapa base ▸ (nenhum, OpenStreetMap, OpenTopoMap, CARTO, Esri imagem/ruas/topográfico, Google Maps mapa/satélite/híbrido/relevo com a sua própria chave de API, URL XYZ ou WMS personalizada, o servidor do mapa de ruas, os termos dos mapas, guardar o mapa da área para o campo; exige georreferência), Chave da API do Google Maps…, URL do mapa personalizado…, Idioma ▸, Tema ▸ (escuro, claro, seguir o sistema), Interface ▸ (tamanho, alto contraste, modo foco, painel lateral recolhido), Snaps e desenho, Camadas ▸ (isolar a camada, mostrar todas as camadas, estados de camadas) |
| Desenhar | Linha, Polilinha, Retângulo, Círculo, Arco, Spline, Hachura, Símbolo, Texto, Cota, Cota angular, Cota radial, Cota de ordenada, Chamada (leader), Curva de nível, Cota de ponto, Área irrigada, Contornar pela imagem, Medir, Perfil de elevação, Comentário, Nuvem de revisão, GPS no campo ▸ (gravar trajeto a pé; terminá-lo como área irrigada, contorno fechado ou linha; marcar ponto na posição atual; descartar o trajeto), Estilo de cota, Foto de campo |
| Zona | Tubo de zona, Lateral (sprayline), Fita/tubo gotejador, Emissor, Válvula de controle, Acessório hidráulico, Junção, Bloco de laterais, Grade de aspersores, Envelope de posição da linha de derivação, Densograma, Dispositivo nas laterais selecionadas, Converter laterais selecionadas em tubo cego, Controlador, Rota de fios, Rotas automáticas de fios, Sistema de dois fios (decodificadores) |
| Linha principal | Fonte de água, Tubo principal, Bomba, Acessório hidráulico, emissor e junção na linha principal, Selecionar bomba, Transientes hidráulicos, Ventosas, Simulação de 24 horas, Operação sob demanda (Clément), Criticidade dos tubos, Calibrar rugosidade com medições, O projeto ao longo da vida (envelhecimento e entupimento), Fertirrigação, Pivô central / lateral móvel, Faixas de carretel, Sulcos com tubo janelado |
| Projeto | Parâmetros de projeto, Catálogo de componentes, Digitalizar curva de uma imagem, Turnos de operação, Tarifa horária e horários dos turnos, Agrupar zonas por energia, Orçamento comercial, Alternativas do projeto, Clima do local, Elétrica da casa de bombas, Bombeamento solar do projeto, Qualidade da água e filtragem, Agronomia ▸ (balanço hídrico diário, risco climático ao longo dos anos, programa de rega, reproduzir o programa na planta, previsão de irrigação, escoamento potencial, fertirrigação por estágio, uniformidade no campo, culturas do usuário), Terreno ▸ (curva de nível, linha de quebra, cota de ponto, perfil de elevação, baixar elevação da internet, gerar curvas de nível do modelo, vista 3D do terreno, limpar perfil, interpolação TIN ou IDW), Projeto automático ▸ (layout automático de aspersores, modelos de gramado esportivo e golfe, dividir talhão em blocos, anéis de gotejamento em pomar, ajustar pivô ao talhão, vários pivôs na propriedade, detectar vegetação na imagem, fileiras da imagem), Verificação do projeto, Boletim de qualidade do projeto, Corrigir automaticamente, Otimizar projeto, Assistente de IA, Dimensionar zonas, Dimensionar linha principal, Projetar tudo, Analisar (tamanhos atuais), Analisar automaticamente ao editar, Vista 3D do terreno, Limpar resultados |
| Relatórios | As abas do painel, Documentos técnicos ▸ (quadro de outorga e automonitoramento, memorial descritivo e de cálculo, plano de operação e manutenção, orçamento por composições, custo do ciclo de vida) |
| Ferramentas | Calculadora de lateral, Bomba e curva do sistema, Golpe de aríete, Bombeamento solar, Bulbo molhado, Orçamento hídrico do paisagismo, Autopropelido (carretel enrolador), Irrigação por superfície (sulcos, faixas, bacias), Tubo janelado, Unidades |
| Ajuda | Tutorial interativo, Boas-vindas e galeria de exemplos, Atalhos de teclado, Mensagens recentes, Pesquisar comandos (Ctrl+K), Manual (F1), Novidades, Relatar problema ou sugerir função, Termos dos dados, Sobre |

## Atalhos de teclado

Com o desenho em foco, digite o alias e **Enter** ou **Espaço**; um alias completo também executa
sozinho após uma pausa. Os aliases aceitam nomes em português, inglês e espanhol (por exemplo
`LINHA`, `LINE`, `LINEA`). A lista completa está em Ajuda → Atalhos de teclado.

| Grupo | Aliases |
|---|---|
| Navegação | `S` seleção · `P` pan · `Z` / `ZE` enquadrar · `ZI` / `ZO` zoom |
| Desenho | `L` linha · `PL` polilinha · `REC` retângulo · `C` círculo · `A` arco · `SPL` spline · `H` hachura · `SY` / `I` símbolo · `T` / `MT` texto · `D` cota · `DAN` cota angular · `DRA` cota radial / de diâmetro · `DOR` cota de ordenada · `LE` chamada · `ME` / `DI` medir · `NOTE` / `NOTA` comentário · `RC` / `NUVEM` nuvem de revisão |
| Terreno | `CT` curva de nível · `BRK` / `QUEBRA` linha de quebra · `SP` cota de ponto · `PR` perfil · `AR` área irrigada |
| Edição | `M` / `MOVER` mover · `CO` / `CP` / `COPIAR` copiar com ponto-base · `COPYCLIP` copiar para a área de transferência · `RO` rotacionar · `MI` espelhar · `SC` escalar · `O` deslocar · `TR` aparar · `EX` estender · `CUT` / `BR` cortar tubo · `ARRAY` matriz · `STRETCH` / `ESTICAR` esticar · `FILLET` / `CONCORDAR` concordância · `CHA` / `CHANFRAR` chanfro · `BREAK` / `QUEBRAR` quebrar em dois pontos · `JOIN` / `UNIR` unir · `X` / `EXPLODIR` explodir · `TOAREA` / `PARAAREA` converter em área · `LEN` / `ALONGAR` alongar · `BO` / `CONTORNO` contorno por clique interno · `TOFRONT` / `FRENTE` e `TOBACK` / `FUNDO` ordem de desenho · `E` apagar · `PA` colar · `U` desfazer · `REDO` · `ALL` selecionar tudo · `DUP` duplicar · `AL` alinhar por 2 pontos · `WBLOCK` / `SB` salvar seleção como bloco · `INSERT` / `INSERIR` inserir bloco · `BEDIT` / `EDITARBLOCO` editar bloco no lugar |
| Seleção e camadas | `SIMILAR` / `SEMELHANTES` selecionar semelhantes · `QSELECT` / `QS` / `FILTRO` seleção rápida · `SELLAYER` / `SELCAMADA` tudo na camada atual · `LASSO` / `LACO` laço · `FENCE` / `CERCA` cerca · `LAYISO` / `ISOLAR` e `LAYUNISO` / `DESISOLAR` isolar a camada, mostrar todas · `LAYCUR` / `PARACAMADA` mover para a camada atual |
| Snap do próximo ponto | `END` · `MID` · `INT` · `PER` · `TAN` · `NEA` · `CEN` · `QUA` · `NOD` · `EXT` (e os nomes em português), digitados durante o desenho (`NON` limpa) |
| Zona | `ZP` tubo de zona · `SL` lateral · `DT` fita · `OUT` / `EM` emissor · `V` válvula · `F` acessório · `J` junção · `B` bloco · `AH` grade de aspersores · `FE` envelope da linha de derivação · `DENS` densograma |
| Elétrica | `CTRL` controlador · `WR` rota de fios · `WROUTE` / `ROTAS` rotas automáticas de fios |
| Linha principal | `MP` tubo principal · `WS` fonte · `PU` bomba · `PV` pivô |
| Projeto automático | `LAYOUT` layout de aspersores · `TPL` / `MODELO` modelos de gramado e golfe · `SUBDIV` / `TALHAO` blocos do talhão · `RINGS` / `ANEIS` anéis de gotejamento · `PFIT` ajuste do pivô · `VEG` vegetação · `WAND` / `VARINHA` contornar pela imagem |
| Análises | `SURGE` / `GOLPE` transientes · `AV` / `VENTOSA` ventosas · `EPS` simulação de 24 horas · `DEMAND` / `DEMANDA` operação sob demanda · `CRIT` criticidade · `CALIB` calibração da rugosidade · `FERT` fertirrigação · `TARIFF` / `TARIFA` horários pela tarifa · `EGROUP` / `ENERGIA` agrupamento por energia |
| Projeto e arquivos | `RUN` projetar · `CHK` verificar · `FIX` corrigir automaticamente · `OPT` otimizar · `IA` / `AI` / `ASK` assistente de IA · `REP` relatórios · `SAVE` · `OPEN` · `OS` snap · `OR` orto · `GS` snap à grade · `GR` grade |

| Tecla | Ação |
|---|---|
| F1 | Manual (o assunto lido por último) |
| F2 | Mostra/oculta relatórios |
| F3 | Liga/desliga snap a objetos |
| F5 | Projetar tudo |
| F7 | Grade |
| F8 | Orto |
| F9 | Snap à grade |
| F10 | Passo do rastreamento polar: desligado, 15°, 30°, 45°, 90° |
| Home | Enquadrar |
| Enter | Conclui a polilinha/lateral em desenho; ao selecionar, repete a última ferramenta |
| Esc | Cancela a ferramenta ou limpa a seleção; uma linha em desenho termina mantendo o que foi traçado |
| Del | Apaga a seleção |
| Backspace | Com a ferramenta de seleção, apaga a seleção; durante o desenho, desfaz o último ponto |
| Tab | Na entrada dinâmica junto ao cursor, mantém o comprimento digitado e passa ao ângulo |
| Shift (segurado) | Trava o segmento em 0°, 45°, 90° |
| Ctrl+Z / Ctrl+Y | Desfazer / refazer |
| Ctrl+A, Ctrl+D | Selecionar tudo, duplicar |
| Ctrl+C / X / V | Copiar, recortar, colar (também entre abas e janelas) |
| Ctrl+S, Ctrl+O, Ctrl+I | Salvar, abrir, importar |
| Ctrl+Alt+N / W / ← / → | Nova aba, fechar aba, alternar abas |
| Ctrl+K | Paleta de comandos |
| Ctrl+Alt+F | Modo foco (só a prancheta) |

Enquanto uma ferramenta espera um ponto, a mesma linha de comando aceita coordenadas na unidade de
exibição: `x,y` absoluto, `@dx,dy` relativo ao ponto anterior, `@d<a` polar (distância e ângulo em
graus, anti-horário a partir do leste) ou só uma distância na direção do cursor, e Enter (`;`
separa números escritos com vírgula decimal). Num projeto georreferenciado ela também aceita
coordenadas de campo: UTM com o seu fuso (`23S 456789 7654321`, ou `UTM 23K 456789 7654321` com a
banda de latitude), UTM no fuso do projeto (`UTM 456789,7654321`) e latitude e longitude
(`LL -22.5,-47.1`, marcas de grau ou letras de hemisfério, graus, minutos e segundos). Um ângulo pode
ser um azimute (`A45`) ou um rumo (`N45E`). Enquanto uma linha está sendo desenhada, `C` a fecha e `U`
desfaz o último ponto; Rotacionar aceita um ângulo digitado, Escalar um fator e Deslocar uma
distância. Ferramentas → Unidades também oferece ft H₂O e kgf/cm² para as pressões.

Os atalhos são capturados nativamente (listener de teclado da janela no navegador,
`HardwareKeyboard` no desktop) e funcionam com qualquer widget em foco, exceto quando um menu ou
um diálogo está aberto.
