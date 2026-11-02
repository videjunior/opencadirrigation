# Interface

## Layout (tela larga)

- **Barra de menus** no topo; à direita, os botões ▶ Projetar e Salvar (âmbar quando há alterações).
- **Abas de projeto** logo abaixo: vários projetos abertos ao mesmo tempo (Ctrl+Alt+N nova aba,
  Ctrl+Alt+W fecha, Ctrl+Alt+←/→ alterna). Copiar e colar (Ctrl+C/X/V) funciona entre abas e
  entre janelas do navegador, levando camadas e itens de catálogo que faltem no destino.
- **Paleta de ferramentas** à esquerda, por grupos (navegação, desenho, edição, terreno, zona,
  linha principal, elétrica, revisão).
- **Canvas** ao centro, com grade, snaps, sobreposições e cartão de progresso do cálculo.
- **Painel lateral** à direita com três abas: **Propriedades** do item selecionado (com resultados
  hidráulicos após o cálculo e o envelope de posição da linha de derivação para laterais), **Camadas**
  (visibilidade, bloqueio, cor, renomear, criar, remover) e **Histórico** (linha do tempo de
  estados, como no Photoshop: clique para voltar ou avançar).
- **Relatórios** embaixo do canvas (F2), redimensionável.
- **Painel do assistente de IA** (opcional, [assistente de IA](ai-assistant.md)) encaixado ao lado
  do canvas, aberto e fechado por Projeto → Assistente de IA… ou pelo botão dele na barra de status.
- **Barra de status** com coordenadas do cursor, snap ativo, comando ou coordenadas digitadas, dica
  da ferramenta, interruptores (snap, orto, grade, rastreamento polar, manter conexões), a precisão
  do GPS enquanto o GPS do aparelho está ligado, o indicador de análise automática, o botão do
  assistente de IA e a versão do app.

Em árabe e urdu todo o layout é espelhado (menus, painéis e diálogos da direita para a esquerda);
o desenho mantém as suas coordenadas.

**Tema**: Ver → Tema → Escuro (o padrão), Claro ou Seguir o sistema (também no menu do celular). A
escolha fica salva e troca na hora, sem perder os projetos abertos, a seleção nem os diálogos
abertos. No canvas claro (branco) as cores do desenho seguem a regra usual dos CADs: branco e
quase branco são desenhados quase pretos e as demais cores claras são escurecidas mantendo o
matiz, para que nada desapareça no fundo; os dados mantêm as suas cores, e a seleção aparece em
magenta em vez de amarelo. Plotagens e exportações (pranchas em PDF, SVG, PNG) são papel e não
mudam com o tema.

## Layout compacto (celular e tablet)

Abaixo de 700 px de largura a tela muda: menu ☰ no topo, barra de ferramentas por grupos embaixo,
botões Concluir/Cancelar no lugar de Enter/Esc, propriedades, relatórios e o assistente de IA em
painéis deslizantes. Pinça para zoom, dois dedos para mover, um dedo desenha.

## Menus

| Menu | Itens |
|---|---|
| Arquivo | Novo projeto, Nova aba de projeto, Fechar aba, Abrir projeto, Projetos recentes ▸, Salvar projeto, Histórico de versões, Salvar automaticamente no navegador (liga/desliga), Exemplos ▸, Importar (DXF, DWG, DGN, PDF, KML/KMZ, SHP, GeoJSON, GPX, LandXML, LAS, EPANET, CSV/XYZ, imagens, GeoTIFF), Georreferenciar imagem selecionada, Alinhar por 2 pontos, Exportar desenho ▸ (DXF, DXF R12, DWG, PDF, SVG, KML, KMZ, GeoJSON, Shapefile, GPX, LandXML, IFC 4, EPANET, PNG), Exportar relatório ▸ (CSV, TXT, XLSX, PDF, programação do controlador), Compartilhar por link, Detalhes do projeto, Georreferência |
| Editar | Desfazer, Refazer, Selecionar tudo, Copiar, Recortar, Colar, Duplicar seleção, Excluir seleção, Materiais da seleção, Salvar seleção como bloco, Inserir bloco, Modificar ▸ (rotacionar, espelhar, escalar, deslocar, aparar, estender, cortar tubo, alinhar por 2 pontos, matriz) |
| Ver | Enquadrar tudo, Aproximar/Afastar, Grade, Rótulos, Raios molhados, Alças de edição, Rótulos condicionais, GPS do aparelho, Sobreposição (nenhuma, velocidade, pressão, diâmetros, pressão mín/máx por zona, densograma, declividade do terreno, exposição do terreno), Mapa base ▸ (nenhum, OpenStreetMap, OpenTopoMap, CARTO, Esri imagem/ruas/topográfico, Google Maps mapa/satélite/híbrido/relevo com a sua própria chave de API, URL XYZ ou WMS personalizada; exige georreferência), Chave da API do Google Maps…, URL do mapa personalizado…, Idioma ▸, Tema ▸ (escuro, claro, seguir o sistema) |
| Desenhar | Linha, Polilinha, Retângulo, Círculo, Arco, Spline, Hachura, Símbolo, Texto, Cota, Cota angular, Cota radial, Cota de ordenada, Chamada (leader), Curva de nível, Cota de ponto, Área irrigada, Medir, Perfil de elevação, Comentário, Nuvem de revisão, GPS no campo ▸ (gravar trajeto a pé; terminá-lo como área irrigada, contorno fechado ou linha; marcar ponto na posição atual) |
| Zona | Tubo de zona, Lateral (sprayline), Fita/tubo gotejador, Emissor, Válvula de controle, Acessório hidráulico, Junção, Bloco de laterais, Grade de aspersores, Envelope de posição da linha de derivação, Densograma, Dispositivo nas laterais selecionadas, Converter laterais selecionadas em tubo cego, Controlador, Rota de fios, Rotas automáticas de fios |
| Linha principal | Fonte de água, Tubo principal, Bomba, Acessório hidráulico, emissor e junção na linha principal, Selecionar bomba, Transientes hidráulicos, Ventosas, Simulação de 24 horas, Operação sob demanda (Clément), Criticidade dos tubos, Calibrar rugosidade com medições, Fertirrigação, Pivô central / lateral móvel |
| Projeto | Parâmetros de projeto, Catálogo de componentes, Turnos de operação, Tarifa horária e horários dos turnos, Agrupar zonas por energia, Orçamento comercial, Alternativas do projeto, Clima do local, Terreno ▸ (curva de nível, linha de quebra, cota de ponto, perfil de elevação, baixar elevação da internet, gerar curvas de nível do modelo, vista 3D do terreno, limpar perfil, interpolação TIN ou IDW), Projeto automático ▸ (layout automático de aspersores, modelos de gramado esportivo e golfe, dividir talhão em blocos, anéis de gotejamento em pomar, ajustar pivô ao talhão, detectar vegetação na imagem), Verificação do projeto, Corrigir automaticamente, Otimizar projeto, Assistente de IA, Dimensionar zonas, Dimensionar linha principal, Projetar tudo, Analisar (tamanhos atuais), Analisar automaticamente ao editar, Vista 3D do terreno, Limpar resultados |
| Relatórios | As abas do painel |
| Ferramentas | Calculadora de lateral, Bomba e curva do sistema, Golpe de aríete, Bombeamento solar, Bulbo molhado, Orçamento hídrico do paisagismo, Autopropelido (carretel enrolador), Irrigação por superfície (sulcos, faixas, bacias), Tubo janelado, Unidades |
| Ajuda | Tutorial interativo, Boas-vindas e galeria de exemplos, Atalhos de teclado, Sobre |

## Atalhos de teclado

Com o desenho em foco, digite o alias e **Enter** ou **Espaço**; um alias completo também executa
sozinho após uma pausa. Os aliases aceitam nomes em português, inglês e espanhol (por exemplo
`LINHA`, `LINE`, `LINEA`). A lista completa está em Ajuda → Atalhos de teclado.

| Grupo | Aliases |
|---|---|
| Navegação | `S` seleção · `P` pan · `Z` / `ZE` enquadrar · `ZI` / `ZO` zoom |
| Desenho | `L` linha · `PL` polilinha · `REC` retângulo · `C` círculo · `A` arco · `SPL` spline · `H` hachura · `SY` / `I` símbolo · `T` / `MT` texto · `D` cota · `DAN` cota angular · `DRA` cota radial / de diâmetro · `DOR` cota de ordenada · `LE` chamada · `ME` / `DI` medir · `NOTE` / `NOTA` comentário · `RC` / `NUVEM` nuvem de revisão |
| Terreno | `CT` curva de nível · `BRK` / `QUEBRA` linha de quebra · `SP` cota de ponto · `PR` perfil · `AR` área irrigada |
| Edição | `RO` rotacionar · `MI` espelhar · `SC` escalar · `O` deslocar · `TR` aparar · `EX` estender · `CUT` / `BR` cortar tubo · `ARRAY` matriz · `E` apagar · `CO` copiar · `PA` colar · `U` desfazer · `REDO` · `ALL` selecionar tudo · `DUP` duplicar · `AL` alinhar por 2 pontos · `WBLOCK` / `SB` salvar seleção como bloco · `INSERT` / `INSERIR` inserir bloco |
| Zona | `ZP` tubo de zona · `SL` lateral · `DT` fita · `OUT` / `EM` emissor · `V` válvula · `F` acessório · `J` junção · `B` bloco · `AH` grade de aspersores · `FE` envelope da linha de derivação · `DENS` densograma |
| Elétrica | `CTRL` controlador · `WR` rota de fios · `WROUTE` / `ROTAS` rotas automáticas de fios |
| Linha principal | `MP` tubo principal · `WS` fonte · `PU` bomba · `PV` pivô |
| Projeto automático | `LAYOUT` layout de aspersores · `TPL` / `MODELO` modelos de gramado e golfe · `SUBDIV` / `TALHAO` blocos do talhão · `RINGS` / `ANEIS` anéis de gotejamento · `PFIT` ajuste do pivô · `VEG` vegetação |
| Análises | `SURGE` / `GOLPE` transientes · `AV` / `VENTOSA` ventosas · `EPS` simulação de 24 horas · `DEMAND` / `DEMANDA` operação sob demanda · `CRIT` criticidade · `CALIB` calibração da rugosidade · `FERT` fertirrigação · `TARIFF` / `TARIFA` horários pela tarifa · `EGROUP` / `ENERGIA` agrupamento por energia |
| Projeto e arquivos | `RUN` projetar · `CHK` verificar · `FIX` corrigir automaticamente · `OPT` otimizar · `IA` / `AI` / `ASK` assistente de IA · `REP` relatórios · `SAVE` · `OPEN` · `OS` snap · `OR` orto · `GS` snap à grade · `GR` grade |

| Tecla | Ação |
|---|---|
| F2 | Mostra/oculta relatórios |
| F3 | Liga/desliga snap a objetos |
| F5 | Projetar tudo |
| F7 | Grade |
| F8 | Orto |
| F9 | Snap à grade |
| F10 | Passo do rastreamento polar: desligado, 15°, 30°, 45°, 90° |
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

Enquanto uma ferramenta espera um ponto, a mesma linha de comando aceita coordenadas na unidade de
exibição: `x,y` absoluto, `@dx,dy` relativo ao ponto anterior, `@d<a` polar (distância e ângulo em
graus, anti-horário a partir do leste) ou só uma distância na direção do cursor, e Enter (`;`
separa números escritos com vírgula decimal).

Os atalhos são capturados nativamente (listener de teclado da janela no navegador,
`HardwareKeyboard` no desktop) e funcionam com qualquer widget em foco, exceto quando um menu ou
um diálogo está aberto.
