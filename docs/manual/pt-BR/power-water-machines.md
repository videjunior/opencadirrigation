# Energia, água e máquinas

Estas análises rodam como uma etapa do cálculo, depois da fiação das válvulas, quando ligadas no seu diálogo, e os
resultados ficam na aba **Energia, água e máquinas** do painel de relatórios e em toda exportação de relatório: a
elétrica da casa de bombas e da alimentação dos pivôs, o bombeamento solar, a análise da água com a sua filtragem e o
seu tratamento, e a fiação das válvulas em dois fios. As configurações ficam no arquivo do projeto em `agb`, só o que
difere do padrão. As faixas de carretel e os conjuntos de sulcos são itens do desenho que o cálculo lê como pontos de
demanda da linha principal. Os diálogos:

| Menu | Diálogo |
|---|---|
| Projeto | Elétrica da casa de bombas…, Bombeamento solar do projeto…, Qualidade da água e filtragem… |
| Projeto → Projeto automático | Vários pivôs na propriedade… |
| Zona | Sistema de dois fios (decodificadores)… |
| Linha principal | Faixas de carretel…, Sulcos com tubo janelado… |

## Elétrica da casa de bombas

Para cada bomba elétrica: o motor (a potência pelos dados da bomba, ou o motor padronizado seguinte à maior potência
no eixo dos seus pontos de trabalho, com o rendimento da classe IE3 da IEC 60034-30-1), a sua corrente, o tipo de
partida (direta, estrela-triângulo, soft-starter ou inversor, com o limite da partida direta definido no diálogo) e o
cabo alimentador dimensionado pela capacidade de condução (NBR 5410, Tabelas 36 a 40, como a IEC 60364-5-52, com a
isolação, o método de instalação, a temperatura e o agrupamento escolhidos), pela queda de tensão em regime (6.2.7) e
na partida (10 % na partida do motor, 6.5.1.3.3), e pelo curto-circuito (IEC 60909). Para a alimentação: o
transformador (NBR 5440) ou o gerador, a corrente de curto-circuito, a carga instalada, a maior demanda simultânea, a
maior partida e o grupo tarifário provável; os pivôs com projeto elétrico podem puxar do mesmo transformador (cabo
dos vãos, anel coletor, torre final). Os números vêm do último cálculo; com *Incluir a elétrica da casa de bombas no
projeto e na lista de materiais*, os cabos, os quadros de partida e o transformador ou gerador entram na lista de
materiais.

## Bombeamento solar do projeto

- **Isolado**: o gerador fotovoltaico do mês de maior necessidade (IEC 62253) para o volume diário de cada mês (pelas
  tabelas de necessidade da cultura, senão o volume que os turnos bombeiam num dia) contra a altura manométrica total
  do projeto, com a irradiação inclinada do local e o índice de desempenho da IEC 61724-1. As bombas não puxam nada
  da rede: o custo de energia do projeto vai a zero, e os meses que o gerador não atende são apontados.
- **Ligado à rede**: o gerador da energia anual de bombeamento, compensado como manda a Lei 14.300/2022 (o Fio B pago
  sobre os créditos conforme o ano faturado; um acesso pedido antes de 7 de janeiro de 2023 não paga Fio B até 2045).
  O custo de energia do projeto desconta o que o gerador dá.

Os módulos, a sua estrutura e o inversor (ou o acionamento da bomba) entram na lista de materiais pelos preços do
diálogo. A calculadora de bombeamento solar do menu Ferramentas continua para uma estimativa rápida.

## Qualidade da água e filtragem

Digite a análise da água (campo vazio = não analisado): fonte, pH, condutividade elétrica, sólidos dissolvidos e em
suspensão, ferro, manganês, cálcio, bactérias e temperatura. O risco de entupimento da água de gotejamento e
microaspersão segue as classes de Nakayama (1982) e de Nakayama e Bucks (1986); o índice de Langelier indica a água
incrustante; a abertura do filtro é uma fração da menor passagem dos emissores (o filtro de areia, de discos ou de
tela que a dá); a cloração (cloro livre contínuo no fim das linhas, ou choques) e o ácido (até o pH desejado) usam as
doses da literatura de extensão, e o injetor dosa na vazão de projeto.

## Sistema de dois fios

*Sistema de dois fios (decodificadores)…* transforma a fiação das válvulas num sistema de dois fios: um par de fios
sai do controlador pelas rotas de fio e passa por todas as válvulas, e um decodificador no par aciona as válvulas ao
alcance do cabo do seu solenoide. Com *Usar dois fios no projeto e na lista de materiais*, o cálculo dimensiona o par
de cada controlador (tensão em cada decodificador, pontos de aterramento) e a lista de materiais traz os
decodificadores, o cabo de dois fios, os para-raios com as suas hastes de aterramento e as emendas no lugar dos fios
das estações. Precisa de um controlador e de rotas de fio (Zona → Rota de fios, ou Rotas automáticas de fios).

## Vários pivôs na propriedade

Selecione o contorno da propriedade (uma área irrigada ou uma polilinha fechada) e, com ele, as formas fechadas a
evitar (reservas legais, estradas, construções, máquinas já desenhadas). O diálogo procura o arranjo de pivôs
centrais de vãos padronizados que irriga a maior área: o maior círculo inteiro primeiro, e malhas de máquinas iguais,
cada uma crescida até onde cabe, com folga entre os círculos e na divisa, dentro da vazão permitida (a outorga; por
padrão a maior vazão da captação), o alcance do aspersor final, o menor raio molhado, o máximo de pivôs e o mínimo e
o máximo de torres. A linha principal comum liga a captação a cada ponto de pivô pela rede mais curta (uma árvore
geradora mínima).

## Faixas de carretel e sulcos

- **Faixas de carretel** (camada TRAVELLERS): faixas paralelas de um carretel enrolador pelo talhão selecionado,
  espaçadas pela tabela de vento do NRCS (NEH 623, cap. 11) para o diâmetro molhado do canhão; cada faixa começa num
  hidrante na borda do talhão e corre o comprimento da mangueira. Cada hidrante é uma demanda da linha principal, com
  a vazão e a pressão que o carretel pede ali (pressão do canhão, perda na mangueira, perda do acionamento, altura do
  canhão e a subida do terreno); as faixas de um mesmo carretel são atendidas uma após a outra, e o relatório dá a
  velocidade para a lâmina desejada, os tempos de percurso e de mudança e a pressão que o projeto deixa no hidrante.
- **Sulcos com tubo janelado** (camada SURFACE_IRRIGATION): os sulcos saem da linha de cabeceira selecionada (o seu
  primeiro ponto é a entrada). O modelo de balanço de volume (FAO 45) acha a vazão por sulco de maior eficiência e o
  tempo de corte para a lâmina; o tubo janelado do conjunto mais distante dá a pressão na entrada, que é uma demanda
  da linha principal, com um turno por posição dos conjuntos.

Os dois são desenhados na prancheta, nas pranchas e nas exportações DXF/DWG, e entram no relatório e na lista de
materiais. As calculadoras de carretel e de tubo janelado do menu Ferramentas continuam para uma estimativa rápida.
