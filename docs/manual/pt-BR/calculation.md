# Cálculo e dimensionamento

## Parâmetros de projeto (Projeto → Parâmetros de projeto)

| Grupo | Parâmetros e padrões |
|---|---|
| Hidráulica | Fórmula de perda de carga: Hazen-Williams (padrão), Darcy-Weisbach, Scobey ou Manning; temperatura da água 20 °C (viscosidade, pressão de vapor e a redução da classe de pressão do PVC e do PE); perdas localizadas como 5 % do comprimento (padrão) ou o K das curvas e tês encontrados no desenho, ligadas; escala e deslocamento do C (envelhecimento); tolerância de conexão 0,05 m; máximo de 100 nós agregados por lateral |
| Velocidades máximas | 2,0 m/s em laterais, 1,5 m/s em zona, 2,0 m/s em linha principal |
| Dimensionamento | Método LP (padrão) ou velocidade + janela de pressão (greedy); diâmetros por lateral (1), por linha de derivação (3) e por linha principal (3); variação máxima de pressão na zona (0 = derivada da tolerância de vazão do emissor); emissores por planta (1) |
| Economia | Juros 10 %, prazo 10 anos, energia 0,75 por kWh, eficiência da bomba 65 %, 2000 h/ano de linha principal e 500 h/ano por zona, balanço capital × energia ligado, moeda da região ou do idioma (veja *Preços e moeda*); frequência da rede elétrica da região, 50 ou 60 Hz (uma bomba de rotação fixa cuja curva foi medida em outra frequência gira na proporção: uma curva de 60 Hz numa rede de 50 Hz roda a 5/6 da rotação e 69 % da altura) |
| Lavagem e segurança | Velocidade de lavagem das fitas 0,3 m/s com pressão mínima de 1 m na ponta aberta; verificação de golpe de aríete ligada com tempo de fechamento de válvula (0 = instantâneo); operação real dos setores, desligada (ligada, depois do cálculo cada setor e pivô de cada turno também roda na pressão que de fato chega à sua válvula, e a aba Linha principal mostra a tabela) |
| Materiais | Seleção automática de conexões ligada; barra de tubo de 6 m para contar luvas |
| Terreno | Interpolação por triangulação (padrão) ou inverso da distância; densificação das curvas 5 m |
| Elétrica | Solenoides de 24 V CA: corrente de partida 0,37 A, de retenção 0,22 A, tensão mínima no solenoide 20 V; folga de fio de 10 % sobre o comprimento da rota |

**Projetos novos**, a última seção do diálogo, diz com o que os próximos projetos novos começam e de
onde vem cada valor (a região da máquina, a sua escolha ou o padrão do programa): a frequência da
rede (60 Hz na América do Norte e Central, no Caribe, no Brasil, na Colômbia, na Venezuela, no
Equador, no Peru, na Guiana, no Suriname, na Arábia Saudita, na Coreia, em Taiwan, nas Filipinas, no
Japão, em várias ilhas do Pacífico e na Libéria, 50 Hz nos demais) e a moeda da região, salvo
escolha sua, e as unidades que você escolheu (as americanas nunca vêm só da região). *Usar estes
parâmetros nos projetos novos* guarda todos os parâmetros do projeto aberto (velocidades, perdas,
economia…) como modelo dos próximos, que mantêm a moeda do seu catálogo (um preço de energia
guardado em outra moeda é convertido); *Voltar ao padrão da região* esquece as escolhas.

## Etapas do cálculo

1. **Construção do grafo**: entidades → nós e trechos; vértices coincidentes fundidos; itens
   pontuais inseridos nos tubos; laterais agregadas; cotas do terreno em cada nó; zonas
   identificadas a partir de cada válvula; conexões (curvas e tês) encontradas quando as perdas
   localizadas vêm delas.
2. **Zonas**, uma a uma:
   - dimensionamento inicial por velocidade máxima, que também fornece as vazões nominais;
   - **LP**: cada trecho dimensionável pode ser composto por frações dos diâmetros candidatos; o
     programa linear minimiza o custo anualizado dos tubos mais o custo de energia da pressão de
     entrada, sujeito à janela de pressão dos emissores críticos (ponta, ponto mais alto e mais
     baixo de cada lateral, cada emissor isolado). Se a análise não confirmar a janela, os emissores
     de pressão mínima e máxima entram como restrições e o LP roda de novo (até quatro rodadas);
   - **classe de pressão**: o LP e os passos gulosos oferecem a cada trecho só os tubos cuja classe,
     na temperatura da água, suporta a pressão que a análise encontrou ali mais o golpe de aríete da
     triagem da etapa 6 (o PVC perde parte da classe acima de 25 °C e o PE acima de 20 °C); quando uma
     passada termina com um tubo abaixo da
     sua pressão, a exigência do trecho sobe e a zona é dimensionada de novo (até três passadas).
     Se nada no catálogo for resistente o bastante, o trecho é dimensionado como antes e a classe
     aparece como excedida;
   - **reparo**: aumento guloso de diâmetro ao longo do caminho crítico até a janela ser atendida
     (quando só o desnível dos emissores já passa da janela, nenhum tubo é comprado por isso e a zona
     avisa: `zone_slope_exceeds_window`);
   - **racionalização**: diâmetros decrescentes de montante para jusante e telescopagem dentro do
     limite de diâmetros por unidade;
   - **análise detalhada**: rede não linear com emissores dependentes da pressão; a pressão a
     jusante da válvula é escolhida por bissecção para que a pressão média dos emissores seja a
     nominal (ou, para fitas reguladas, para garantir a pressão mínima da linha de derivação);
   - resultados: vazão da zona, pressões mínima e máxima e admissíveis, variação admissível e real,
     pressão requerida na válvula, perda na válvula, uniformidade (CU de Christiansen, DU do quartil
     inferior, EU de Keller-Karmeli com o CV do fabricante e emissores por planta, uniformidade
     estatística, variação de vazão), CU de sobreposição para aspersores com raio molhado, tabela de
     tubos com pressões, cotas e velocidades, tabela de emissores.
3. **Linha principal**, por turno: demanda e pressão requerida de cada válvula, pivô (o que o seu
   pacote de aspersores pede) e estação de aspersores com válvula programada, LP sobre todos os
   turnos com custo de energia ponderado pelas horas de cada um e as mesmas passadas de classe de
   pressão; numa linha principal em anel o LP leva o balanço de energia de cada anel para as vazões
   com que dimensiona, e como os diâmetros decidem como a vazão se divide ele é resolvido de novo com
   as vazões dos novos diâmetros até a escolha se firmar (até mais quatro vezes; uma nota de
   aproximação fica só quando as vazões não se acomodam). Com fonte calculada, a linha piezométrica
   fica acima do tubo nos pontos altos do perfil (no LP e na análise), e um ponto alto sem ventosa é
   apontado (`air_valve_missing`, informação). Depois, a análise de cada turno com bombas (ponto de
   operação; um inversor encontra a rotação que mantém a pressão alvo na saída; o NPSH disponível é
   comparado com a curva da bomba; uma estação de bombeamento liga as bombas em serviço que o turno
   pede, escalonadas pela vazão, na curva conjunta das que funcionam, com o ponto de cada uma),
   válvulas com piloto redutor ou sustentador, válvulas redutoras, sustentadoras e controladoras de
   vazão, válvulas de retenção e fontes de pressão fixa ou calculada; duty de cada fonte (vazão,
   pressão disponível, requerida, déficit) e energia anual. Com a operação real dos setores ligada,
   cada setor e pivô roda então na pressão que a linha principal entrega a ele, como um emissor
   equivalente atrás da sua válvula (uma válvula que regula mantém o seu ajuste, um piloto
   sustentador a sua pressão de montante), reajustado até o setor e a linha concordarem.
4. **Telescopagem**: tubos com mais de um diâmetro são divididos em entidades, maior diâmetro a
   montante, e as zonas afetadas são reanalisadas.
5. **Lavagem**: cada zona com fitas é analisada com as pontas abertas na velocidade de lavagem;
   reporta vazão de lavagem, pressão necessária na válvula e a montante, número de fitas, pressão
   mínima na ponta e velocidade máxima.
6. **Golpe de aríete**: ao longo do caminho da água desde a fonte (desde a válvula, numa zona), cada
   ponto de um tubo recebe a envoltória de Michaud na sua distância x, min(a·ΔV/g, 2·x·ΔV/(g·T)), com
   a celeridade da onda a pelo material e pela parede e o tempo de fechamento T, sobre a pressão
   estática ali; o pior ponto de cada entidade é comparado com a classe do tubo e o relatório mostra o
   caminho usado (a análise completa de transientes fica em Linha principal → Transientes
   hidráulicos…, adiante).
7. **Máquinas mecanizadas**: o pacote de aspersores e a tabela do temporizador de cada pivô central
   e linear e, quando os dados são informados, o braço de canto, a prescrição de taxa variável e o
   projeto elétrico (veja *Agronomia, máquinas mecanizadas e calculadoras de campo*).
8. **Fiação das válvulas** (quando o desenho tem controlador ou rota de fios): menor caminho de cada
   controlador até cada válvula, estações em ordem de distância e, para cada controlador, o fio
   comum e o fio de estação de cada válvula de menor custo tal que cada solenoide, ao abrir
   (corrente de partida) com as outras válvulas do seu turno já ligadas (corrente de retenção), tenha
   pelo menos a tensão mínima. A queda é `I·R·L` no fio de estação mais, em cada trecho do comum, a
   corrente das válvulas além dele; os comprimentos incluem a folga. Sem turnos, todas as válvulas
   ficam ligadas juntas, como no cálculo hidráulico. Uma válvula mestra fica ligada com todas as
   zonas (saída 0, fio próprio, a sua corrente no comum), e cada estação de aspersores com válvula
   ocupa uma estação com os aspersores em paralelo. Informa estações, comprimentos de rota e de fio,
   bitolas, tensões nos solenoides e a corrente de pico de cada controlador; avisa sobre válvulas
   sem fio, rotas que não chegam a um controlador, controladores com poucas estações ou abrindo
   mais válvulas do que acionam juntas e tensões abaixo da mínima.
9. **Materiais**: tubos por diâmetro e classe, emissores, fitas, válvulas, acessórios, bombas
   (com seleção automática a partir do catálogo e motor padrão IEC; horímetros das bombas), pivôs
   com torres, aspersores e reguladores, **conexões selecionadas automaticamente** da geometria
   (luvas por barra, cotovelos, tês, cruzetas, reduções, tampões, derivações de lateral, finais de
   fita, hastes) e os itens elétricos (fios por bitola, controladores e os seus acessórios, dois
   conectores à prova d'água por válvula), com custos, códigos FINAME quando o catálogo os traz,
   custo anualizado (fator de recuperação de capital) mais energia; também separados por setor
   (Materiais por setor) e para a seleção atual (Editar → Materiais da seleção…). As bombas de reserva
   das estações de bombeamento, os vasos de ar, as referências de bloco marcadas para contar, as
   faixas de carretel e os sulcos e, quando ligados, os itens da elétrica da casa de bombas, do gerador
   solar e do sistema de dois fios ([Energia, água e máquinas](power-water-machines.md)) também
   entram. O comprimento dos tubos segue o terreno (√(L² + Δz²) com o terreno nas duas pontas), nas
   perdas como na lista de materiais.

O cálculo roda num **Web Worker** no navegador (ou num isolate no desktop) e devolve à interface as
entidades redimensionadas e os resultados; enquanto ele roda, a edição é bloqueada para não perder
alterações (salvo se *Editar durante o cálculo* estiver ligado em Ver → Snaps e desenho…: o cálculo
trabalha então numa cópia e os resultados dele, desatualizados, são descartados), mas navegação,
relatórios e outras abas seguem livres; o cartão de progresso tem um Cancelar. Com Projeto → Analisar
automaticamente ao editar, um instante depois de cada edição o projeto é analisado de novo sem
redimensionar, e pressões, vazões e mensagens acompanham o desenho (um indicador na barra de status
mostra isso).

## Verificação de projeto

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
| `zone_mixed_emitters` | aviso | Zona que mistura gotejamento com aspersão, ou aspersores cujas taxas de aplicação diferem mais de 1,8 vez (sprays com rotores, setores sem bocais equivalentes) |
| `zone_dead_end`, `area_no_emitters`, `no_terrain`, `looped_mainline`, `no_hydraulics` | informação | Situações que merecem atenção mas não impedem o cálculo |
| `elec_stations`, `elec_voltage` | erro | Controlador com menos estações que válvulas ligadas a ele; tensão no solenoide abaixo da mínima mesmo com o fio mais grosso habilitado |
| `elec_unwired`, `elec_wire_orphan`, `elec_ctrl_unwired`, `elec_no_controller`, `elec_no_wires`, `elec_simultaneous` | aviso | Válvula sem fio até um controlador; rota que não chega a nenhum controlador; controlador fora das rotas; rotas sem controlador; nenhum fio habilitado no catálogo; turno que abre mais válvulas do que o controlador aciona juntas |
| `area_self_intersect` | erro | Uma área irrigada cujo contorno cruza a si mesmo (a sua área, e a sua água, saem erradas); a correção a divide em áreas simples |
| `pipes_overlap`, `outside_terrain`, `zone_spacing_wide`, `area_uniformity_low` | aviso | Tubos ou laterais sobrepostos; itens a mais de 10 m fora dos dados de terreno (cota extrapolada); aspersores de círculo completo mais espaçados do que o alcance permite; uma área regada de forma desigual pelos seus aspersores (densograma: CU abaixo de 75 %, DU abaixo de 60 % ou mais de 5 % da área recebendo menos da metade da média) |
| `area_rate_exceeds_soil`, `area_eto_climate`, `area_planting_date`, `area_leaching_infeasible` | aviso | Aspersores aplicando mais do que o solo e a sua declividade absorvem; uma ETo digitada numa área diferente da do clima do local; data de plantio ambígua ou inválida; água salina demais para a cultura |
| `capacity_below_peak`, `pivot_capacity_below_peak`, `pivot_runoff` | aviso | O sistema, ou uma máquina, sem capacidade para a demanda de pico na janela de rega; escoamento sob uma máquina ([Agronomia e manejo da irrigação](agronomy.md#verificações)) |
| `supply_no_meter` | informação | Uma fonte de água sem medidor de vazão nem horímetro, que o automonitoramento de uma outorga pede |

## Mensagens do cálculo

Cada zona, turno e etapa pode emitir avisos, mostrados na aba Mensagens e junto ao item: pressão
fora da janela, velocidade excedida, classe de pressão excedida (em operação ou por golpe de aríete),
válvula fora da faixa de vazão, bomba fora da curva, NPSH disponível abaixo do que a bomba exige,
inversor que não alcança a pressão alvo ou que precisaria de rotação abaixo da mínima, fonte com
vazão ou pressão excedida, déficit de pressão na válvula, no pivô ou numa estação de aspersores com
válvula (ou estação acima da janela, ou fora de todos os turnos), LP inviável (com o método guloso
assumindo), linha principal em anel (o LP leva o balanço de energia de cada anel e repete com as
novas vazões; a análise final confere), componentes de catálogo ausentes, taxa de aplicação do pivô
acima do limite do solo, bomba abaixo da vazão mínima da sua curva ou acima da potência do motor, LP
interrompido no limite de iterações (o método guloso dimensiona), desnível de um setor maior que a
janela dos emissores, setor que um dispositivo regulador mantém abaixo da pressão nominal, pressão
abaixo da atmosférica num tubo (a linha piezométrica abaixo dele), sobra de pressão numa válvula de
setor que não regula, estação ou turno que pede mais corrente do que o controlador dá, os turnos de
um dia que não cabem na janela de rega, entre outras.

## Assistente de projeto: explicações e correção com um clique

A aba Mensagens e a verificação do projeto mostram cada problema num cartão: o que aconteceu,
**por que importa** e **como resolver**, um botão para mostrar o item no desenho, **Perguntar à IA**
(que abre o assistente de IA com uma pergunta sobre aquela mensagem; nada é enviado antes de você
clicar em Enviar) e, quando existe, um botão que corrige (cada correção é um passo de desfazer).
Além do desenho e dos resultados, o assistente confere **configurações impossíveis**: velocidade,
horas, parâmetros econômicos, tolerância, variação na zona ou temperatura da água fora das faixas
físicas, nenhum tubo habilitado no catálogo para um uso, máximos da fonte abaixo dos valores de
projeto, zonas fora de todos os turnos, turnos vazios, pressão do emissor fora da faixa do bocal,
rotação da bomba fora da faixa.

- **Correções**: ligar um item solto ao lado do tubo, remover tubos de comprimento zero, vértices
  repetidos e duplicados, renomear zonas repetidas, escolher (ou inserir) a bomba de menor custo de
  ciclo de vida, trocar por submersa a bomba de superfície que não consegue succionar, tubo de
  classe de pressão maior, válvula do tamanho certo, dividir as zonas em mais turnos, voltar aos
  parâmetros padrão, pôr num turno as zonas esquecidas, a pressão nominal do emissor, controlador com
  estações suficientes (o próximo tamanho padrão), habilitar os fios do catálogo, dividir uma área
  que cruza a si mesma em áreas simples, manter só um de dois tubos desenhados um sobre o outro, ligar
  um aspersor solto ao tubo mais próximo por um tubo curto, usar os máximos da fonte no projeto, entre
  outras.
- **Corrigir automaticamente** (menu Projeto, `FIX`): correções seguras e cálculos em rodadas até
  não haver mais o que corrigir, tudo num único passo de desfazer, com um resumo do que mudou e do
  que depende de uma decisão sua (bomba na rede pública, turnos novos: nunca aplicados sozinhos).
- **Otimizar projeto** (menu Projeto, `OPT`): menor custo anual (investimento anualizado + energia)
  que atende todos os requisitos — dimensionamento LP, as menores válvulas adequadas e a bomba de
  menor custo de ciclo de vida — por etapas, cada uma mantida só se melhorar e não trouxer aviso
  novo, com comparação antes / depois.
- Os dois listam cada correção ou mudança com uma caixa e um botão que a mostra no desenho: *Manter
  só as marcadas* volta o projeto ao que era e refaz só essas, num passo de desfazer.
- Depois de um cálculo com erros a aba Mensagens abre sozinha e mostra quantos problemas há.

## Análises da linha principal e da operação

Rodam sobre o projeto calculado (cada uma diz o que falta quando não há cálculo ou fonte de água);
o que propõem (ventosas inseridas, horários, turnos, rotas de fios, um fator de C) é aplicado num
único passo de desfazer. As longas (operação sob demanda, criticidade, calibração, a tarifa horária,
o agrupamento por energia, o projeto ao longo da vida) mostram o progresso e param com Cancelar.

| Análise | Menu, alias | O que faz |
|---|---|---|
| Transientes hidráulicos | Linha principal, `SURGE` | Método das características na linha principal de cada turno: as válvulas de zona fechando no tempo de fechamento, uma queda de energia desligando as bombas (inércia estimada pela potência e pela rotação, mais o volante de inércia da bomba; retenções fechando no fluxo reverso) e um registro fechando; celeridade da onda pela parede de cada tubo, cavidades de vapor (separação de coluna), as ventosas desenhadas agindo como ventosas combinadas e os vasos de ar das junções da linha principal; envoltórias de carga e de pressão por tubo contra a classe e contra o vácuo, o perfil ao longo do caminho crítico, séries temporais na bomba e no pior ponto, e as constatações. Para com Cancelar entre uma rodada e outra. |
| Ventosas | Linha principal, `AV` | Perfil de cada caminho de uma fonte até uma ponta da linha principal e as ventosas que a prática do manual AWWA M51 pede (pontos altos, mudanças de declividade, trechos longos, recalque da bomba, retenções, pontas da linha, linha piezométrica baixa, vácuo do transiente), dimensionadas pela vazão de ar no orifício e inseridas com o item de catálogo que serve. |
| Simulação de 24 horas | Linha principal, `EPS` | Os turnos ao longo de um dia nos seus horários e durações, cada bomba ligada enquanto um turno que ela atende está rodando; energia e custo por bomba e por hora na tarifa dos parâmetros, com um horário de ponta opcional; o nível de cada reservatório ou açude de uma fonte desce e sobe com a vazão que entra. |
| Operação sob demanda | Linha principal, `DEMAND` | Vazões de projeto de uma rede ramificada de hidrantes pela fórmula de Clément e a verificação contra configurações aleatórias de hidrantes abertos (FAO 59): confiabilidade e déficit de pressão por hidrante; os hidrantes podem ter limitador de vazão. |
| Criticidade dos tubos | Linha principal, `CRIT` | Cada tubo fechado por vez (N−1): a demanda cortada e a demanda que as pressões restantes não atendem, com os tubos ordenados. |
| Calibração da rugosidade | Linha principal, `CALIB` | Fatores do C de Hazen-Williams (um só, ou um por grupo de material) ajustados a pressões e vazões medidas no campo, por mínimos quadrados ponderados com o solver de rede no laço. |
| O projeto ao longo da vida | Linha principal | O projeto calculado analisado de novo com os seus tubos depois de anos de uso: os tubos mais rugosos (o C de Hazen-Williams caindo tantos pontos por ano, a rugosidade de Darcy-Weisbach crescendo tantos milímetros por ano), os emissores em parte entupidos (menos vazão, mais variação de fabricação) e os dois, ao lado do projeto novo: vazões, pressões dos emissores, EU e CU, setores fora da janela, a pressão que falta nas válvulas, o que as fontes e as bombas precisam dar e a energia, para mostrar a margem do projeto. |
| Fertirrigação | Linha principal, `FERT` | Tempos de chegada de um produto injetado na fonte ou na bomba até cada válvula e até o emissor mais distante, o plano de injeção (pré-molhamento, injeção, lavagem), as quantidades para uma dose por hectare e a verificação de um injetor venturi. |
| Tarifa horária e horários dos turnos | Projeto, `TARIFF` | Preço da energia por faixa do dia, demanda contratada e estações do ano, e o desconto da irrigação rural brasileira (uma janela de até 8 h 30 min por dia em até três blocos, nunca entre 17h00 e 21h30, Resolução Normativa ANEEL nº 1.000/2021, art. 186, e Portaria Normativa MME nº 137/2026); os horários de menor custo diário. |
| Agrupar zonas por energia | Projeto, `EGROUP` | Zonas (e pivôs e estações de aspersores com válvula) agrupadas em turnos de altura requerida parecida, para que a bomba não dê a cada zona a pressão da mais exigente; comparado com o agrupamento por vazão. |
| Rotas automáticas de fios | Zona, `WROUTE` | Rotas de fios ao longo das valas dos tubos de cada controlador até as suas válvulas, válvulas mestras e relés de partida de bomba (menores caminhos na fiação convencional, uma árvore do tipo Steiner num percurso de dois fios), e o dimensionamento de um sistema de dois fios (decodificadores) sobre elas: decodificadores, cabo, tensão em cada decodificador, pontos de aterramento. |

## Agronomia, máquinas mecanizadas e calculadoras de campo

- **Clima do local** (Projeto → Clima do local…): normais mensais de ETo (Penman-Monteith FAO),
  chuva (média e provável), radiação solar, umidade mínima e vento a 2 m, baixadas para o local da
  NASA POWER (o padrão, livre para qualquer uso) ou do Open-Meteo (histórico meteorológico, ERA5; para
  uso não comercial), lidas de um arquivo de estação do INMET, calculadas a partir das normais de uma
  estação, ou digitadas, guardadas no projeto com a sua origem. O balanço hídrico diário do solo, o
  programa de rega, a fertirrigação por estágio, a uniformidade no campo e as culturas do usuário estão
  em [Agronomia e manejo da irrigação](agronomy.md); a elétrica da casa de bombas, o bombeamento solar
  no projeto, a qualidade da água, a fiação em dois fios, os vários pivôs, as faixas de carretel e os
  sulcos em [Energia, água e máquinas](power-water-machines.md).
- **Necessidade por cultura** (aba de relatório): cada área irrigada com uma cultura da tabela
  FAO-56 ganha a sua tabela por mês e fase de desenvolvimento a partir do clima do local, do solo
  (12 classes texturais do USDA), do método de chuva efetiva (USDA-SCS, FAO/AGLW, empírico da FAO,
  uma fração da chuva), da necessidade de lixiviação para a salinidade da água (FAO-29) e, no
  gotejamento, da redução do Kc pela cobertura do solo; totais por área e a categoria de
  licenciamento da Resolução CONAMA 284/2001 por método e área (informativa).
- **Máquinas mecanizadas**: as Propriedades de um pivô central ou linear abrem **Pacote,
  temporizador, braço, VRI e elétrica…**: o pacote de aspersores (vazão por saída para uma lâmina
  uniforme, reguladores, pendurais, bocais numerados ou do catálogo, canhão final e booster), a
  tabela do temporizador pela transmissão, um braço de canto que segue um caminho guia (com o aviso
  de salto), uma prescrição de taxa variável por zonas ou setores (CSV) e o projeto elétrico (queda
  no cabo vão a vão, partida dos motores, tamanho do gerador). As abas Pacote do pivô e Braço, VRI e
  elétrica os listam.
- **Calculadoras** (menu Ferramentas): lateral (comprimento máximo, perdas e uniformidade de uma
  lateral ou fita em declive); bomba e curva do sistema (ponto de operação, potência e energia
  anual); golpe de aríete (sobrepressão de Joukowsky contra a classe do tubo); bombeamento solar
  (gerador fotovoltaico para o volume diário de cada mês, com a comparação com a rede); bulbo
  molhado de um gotejador e a fração molhada da área; orçamento hídrico do paisagismo (MAWA e ETWU,
  com tempos de ciclo e infiltração); autopropelido (espaçamento entre faixas, velocidade, lâmina,
  perda na mangueira, pressão de entrada); irrigação por superfície (sulcos, faixas e bacias por
  balanço de volume: avanço, corte, eficiências); tubo janelado (aberturas das janelas ou diâmetros
  dos furos para uma vazão por sulco).
