# Catálogo de componentes

O catálogo do projeto tem sete grupos: **tubos**, **emissores** (com bocais), **fitas**, **válvulas
e acessórios**, **bombas**, **conexões** e **fios**. Todos os valores hidráulicos internos estão em SI.

| Grupo | Campos principais |
|---|---|
| Tubos | DN, diâmetro interno, material (que define os coeficientes de Scobey e de Manning e a redução da classe de pressão do PVC e do PE com água quente), C de Hazen-Williams, rugosidade, classe de pressão, uso (lateral, zona, linha principal), custo por metro, fornecedor, código |
| Emissores e bocais | Tipo (aspersor, microaspersor, gotejador, borbulhador, canhão, ponto de demanda), curva `q = k·H^x`, raio molhado `R = a·H^b`, arco, pressão padrão, mínima e máxima, CV de fabricação, tolerância de vazão, diâmetro de entrada, altura da haste, custo; a curva de um bocal pode ser ajustada pelas linhas da tabela do fabricante (pressão, vazão e raio colados como tabela), e um perfil radial medido (ensaio de coletores) alimenta o densograma |
| Fitas | Diâmetro interno, espaçamento e curva do emissor, coeficiente de barb, CV, pressão de entrada padrão, mínima e máxima, tolerâncias acima e abaixo, classe, custo por metro |
| Válvulas e acessórios | Tipo (zona, mestra, PRV, sustentadora de pressão, controladora de vazão, registro, retenção, anti-refluxo, filtro, hidrômetro, ventosa, outro), diâmetro, perda `h = K·Q^n + C`, vazões mínima e máxima, ajuste padrão, custo |
| Bombas | Pontos (Q, H) ajustados a uma parábola, rendimento (ou uma curva de rendimento), curva de NPSH requerido, potência, vazão máxima, submersa ou de superfície, a frequência da rede em que a curva foi medida, custo |
| Conexões | Tipo (luva, cotovelo 90° e 45°, tê, cruzeta, redução, tampão, adaptador, derivação de lateral, final de fita, haste), diâmetros, custo |
| Fios | Seção do condutor (mm²), resistência (Ω/km), custo por metro, fornecedor, código; colunas CSV `mm2` ou `awg`, `ohmKm` (supõe-se cobre quando só a seção é dada) |

Qualquer item também pode trazer o código FINAME com que está credenciado para financiamento no
BNDES; a lista de materiais e o orçamento o mostram.

O editor mostra e recebe os valores nas unidades do projeto e os guarda em SI: num projeto em
unidades americanas, diâmetros em polegadas, classes e pressões na unidade de pressão (psi, bar,
kPa, ft H₂O), espaçamentos e preços por pé, as vazões das válvulas e as curvas da bomba (Q@H,
rendimento, NPSH) em gpm; um projeto métrico padrão não muda. O CSV exportado também sai nas
unidades do projeto, com a unidade no nome de cada coluna (`nominal_in`, `rating_psi`, `spacing_ft`,
`maxQ_gpm`, `points_gpm_psi`, `cost_per_ft`), e a importação lê essas colunas e as de listas de preço
("DN (in)", "PN (psi)", "Cost (per ft)", `q_gph`).

O **catálogo padrão** traz 17 tubos (PE 16–50 mm, PVC DN 35–250, PEAD 110 e 160, aço 6"), 10 famílias
de emissores (gotejadores PC e turbulentos, microaspersores, borbulhador PC, aspersor de impacto,
canhão, rotor e spray de jardim, ponto de demanda), 6 fitas e tubos gotejadores, 36 válvulas e
acessórios (1" a 6", entre eles válvulas mestras, sustentadoras de pressão e hidrantes com limitador
de vazão), 18 bombas (centrífugas de 1 a 100 cv, submersas de 3 a 30 cv) e cerca de 330 conexões
geradas para cada diâmetro nominal (luvas, cotovelos de 90° e 45°, tês, cruzetas, tampões,
adaptadores e reduções, mais conectores de lateral, finais de linha e tubos de subida) e 12 fios de
cobre (1 a 10 mm² habilitados, AWG 18 a 8 desabilitados: habilite-os onde a bitola AWG é a norma),
com nomes traduzidos e preços ilustrativos. Os tubos de PVC PN 80 têm os diâmetros internos e as
paredes da NBR 14312 até DN 150 e da ISO 1452-2 S 12,5 acima, os de PE PN 6 a parede do PE 80 SDR 21,
os bocais do aspersor de impacto um coeficiente de descarga de 0,96 e cada bomba um motor que a sua
curva cabe. Uma verificação de plausibilidade roda sobre o catálogo padrão e todos os pacotes: a
tensão de anel de uma parede termoplástica contra a sua classe, um bocal que não passa mais que um
orifício ideal do seu diâmetro, a potência hidráulica dentro de 0,85 da do motor com o seu fator de
serviço (NEMA MG 1).

O editor (Projeto → Catálogo de componentes…) edita, duplica e remove itens, importa e exporta JSON,
CSV por grupo e **Excel** (exporte, preencha preços na planilha e importe de volta), define o
catálogo padrão para novos projetos (*Usar como padrão para novos projetos*) e, como ações separadas
que perguntam antes, dizendo quantos itens saem e quantos objetos os usam, *Restaurar o catálogo de
fábrica…*, *Carregar meu padrão…* e *Esquecer meu padrão…*. Uma linha importada sem id ganha um id
estável (pelo fornecedor, código e nome), então a mesma linha importada de novo atualiza o próprio
item e nunca o de outra lista; substituir um item que o desenho usa é avisado, e linhas sem diâmetro,
curva ou seção ficam de fora com aviso. O CSV segue a RFC 4180; a coluna `kv` é o coeficiente de vazão
das fichas técnicas (Δp = (Q/Kv)² bar) e `kcoef` o K de K·v²/2g; um PN sem unidade até 25 é perguntado
(bar ou metros de coluna d'água). Um item desativado ou removido que o desenho ainda usa aparece como
ele mesmo, marcado, nas Propriedades.

## Digitalizar curva de uma imagem

**Projeto → Digitalizar curva de uma imagem…** (logo abaixo de *Catálogo de componentes…*; no celular ☰ → Projeto)
lê uma curva de uma imagem de gráfico (uma página de catálogo, uma captura de tela, a foto de uma folha de dados) e a
põe no catálogo do projeto. Nada sai do aparelho. Ela lê três tipos de gráfico:

- **Bomba**: a altura × vazão e, como curvas a mais da mesma imagem, o rendimento, o NPSH requerido e a potência no
  eixo, compartilhando o eixo horizontal (vazão), cada uma com o seu eixo vertical.
- **Emissor ou aspersor**: a vazão × pressão (marque *Vazão no eixo horizontal* quando o gráfico for desenhado assim),
  ajustada a q = k·Hˣ.
- **Perfil radial de aspersor**: a taxa de aplicação × a distância do aspersor.

**Como usar.**

1. Abra a imagem (*Abrir imagem…*), cole-a (Ctrl+V de uma captura de tela) ou solte o arquivo na janela. Lê PNG, JPEG e
   WebP; uma foto é desvirada pela etiqueta EXIF, e uma imagem com mais de 3200 pixels é reduzida.
2. **Eixo horizontal**: clique em duas marcas do eixo bem afastadas e digite os valores delas; escolha a unidade e,
   numa escala logarítmica, *Logarítmico*. **Eixo vertical**: o mesmo no eixo vertical da curva. A ferramenta passa
   sozinha à etapa seguinte depois do segundo clique de cada eixo.
3. **Pontos**: clique ao longo da curva. Arraste um ponto para movê-lo; selecione um e tecle Delete (ou *Excluir
   ponto*, ou o botão direito) para removê-lo; *Desfazer* volta a última mudança. A roda do mouse ou a pinça dão zoom,
   arrastar a imagem desloca, e um botão no canto mostra a imagem inteira de novo. Uma lupa acompanha o mouse; na tela
   de toque, um toque longo mostra a lupa e o ponto vai para onde o dedo sai.
4. Ou **Traçado automático**: defina os dois limites ao longo do eixo horizontal (*De*, *Até*) e o número de pontos e
   clique sobre a curva. A cor dela é seguida para os dois lados e os pontos são colocados igualmente espaçados; depois
   é só corrigir. Aumente a *Tolerância de cor* para uma linha fraca ou borrada e diminua quando o traçado pular para
   outra coisa.
5. Confira o **Ajuste**: a curva ajustada aparece sobre a imagem, e a tabela lista cada ponto com o seu resíduo.
6. Escolha o destino e clique em **Aplicar ao catálogo**: uma etapa de desfazer. *Exportar CSV* e *Copiar pontos* dão os
   pontos nas unidades dos eixos. A imagem, a calibração e os pontos ficam com a aba enquanto o diálogo está fechado
   (não no arquivo do projeto).

**Para onde vai.**

- **Bomba**, nova ou existente: os pontos de altura substituem a curva da bomba (o motor de cálculo os ajusta como
  ajusta uma folha de dados: a parábola de mínimos quadrados quando ela fica a até 3 % da maior altura, a tolerância de
  altura do grau 1B da ISO 9906, senão a curva monótona pelos pontos), e a faixa de vazões deles passa a ser a vazão
  mínima e máxima da bomba; os pontos de rendimento substituem a curva de rendimento (o melhor valor vira o rendimento
  único); os de NPSH substituem a curva de NPSH. Sem curva de rendimento, a potência no eixo dá o rendimento em cada
  ponto de potência, η = ρ·g·Q·H / P, com H lido na curva de altura ajustada. Uma bomba sem potência nominal recebe a
  maior potência lida. Uma bomba nova precisa de pelo menos três pontos de altura.
- **Emissor**: um emissor novo (um bocal, as pressões do gráfico como faixa e a do meio como padrão), um bocal de um
  emissor do catálogo ou o emissor de uma fita gotejadora. Só k e x mudam: o raio molhado e o início da compensação de
  pressão ficam.
- **Perfil**: o perfil medido de um bocal (distância sobre o raio molhado lido, taxa sobre a maior), que o densograma
  usa com *Usar o perfil medido dos bocais que o têm*.

**Método.** Os dois pontos de cada eixo dão os valores e a direção dele (o valor vertical não muda ao longo do eixo
horizontal, e vice-versa): o mapeamento afim geral u = a·x + b·y + c, v = d·x + e·y + f, com u e v os valores, ou os
logaritmos decimais deles num eixo logarítmico, por isso imagens giradas ou inclinadas são lidas corretamente. A
calibração é recusada, com o motivo, quando os dois pontos de um eixo estão no mesmo lugar, os dois valores dele são
iguais, um eixo logarítmico tem valor nulo ou negativo, ou os dois eixos foram clicados a menos de 10° um do outro. O
traçado automático pega a cor clicada (o pixel vizinho que mais difere do fundo) e fica com os pixels cuja cor está
entre o fundo e essa cor (a borda suavizada de uma linha conta; uma linha de grade clara ou uma curva de outra cor
não); ele segue a curva pixel a pixel ao longo do eixo horizontal, ficando com o trecho de pixels mais próximo de onde
os últimos passos levam, atravessa falhas curtas (uma linha de grade desenhada por cima, um rótulo) e para nas longas.
Os pontos vazão × pressão são ajustados a q = k·Hˣ por mínimos quadrados em escala log–log, e os da bomba como acima.
O assistente lê um gráfico de uma imagem anexada com a própria visão e faz o mesmo com `fit_curve_points`,
`apply_curve_points` e `export_curve_points`.

**Limites.** Uma foto tirada de lado (perspectiva) não é afim e é lida só de forma aproximada: fotografe a página de
frente ou use um escaneamento. O traçado supõe um valor da curva para cada valor horizontal, como nas curvas de
catálogo; um gráfico com vários diâmetros de rotor é lido um diâmetro por vez. A curva de potência é tomada como
potência no eixo (P2): de um gráfico da potência absorvida pelo motor (P1) sai o rendimento global, então nesse caso
ponha o rendimento do motor da bomba em 100 %. A frequência nominal da bomba, o raio molhado de um bocal e os custos
não são lidos da imagem: ajuste-os no catálogo.

## Preços e moeda

Todos os preços de um projeto (catálogo, tarifa de energia, máquinas de pivô) estão em uma única
moeda, guardada como código ISO 4217 junto com o símbolo mostrado nas tabelas e relatórios
(Projeto → Parâmetros de projeto → Moeda). Um projeto novo usa a moeda da região da máquina quando a
localidade do sistema no idioma da interface indica uma (`pt-PT` → EUR, `en-IN` → INR, `de-CH` → CHF);
senão, a moeda do país mais populoso do idioma (pt BRL, en USD, es MXN, de/fr EUR, ja JPY, zh CNY,
hi/mr/te/pa INR, bn BDT, ur PKR, ar EGP, ru RUB, tr TRY, id IDR, vi VND, ha NGN, sw TZS). Os preços
ilustrativos do catálogo padrão e a tarifa de energia padrão (0,75 R$/kWh) estão em reais e são
convertidos por câmbios de referência (Banco Central Europeu e exchangerate-api.com, 21/09/2026), de
modo que todos os idiomas chegam ao mesmo projeto; eles só ordenam as opções do dimensionamento
econômico e devem ser trocados pela tabela de preços local. Escolher outra moeda pergunta se todos os
preços devem ser convertidos, com o câmbio de referência sugerido e editável, e ela passa a ser a
moeda dos novos projetos. O catálogo padrão salvo guarda a sua moeda e é convertido para projetos em
outra. Os exemplos da galeria usam a moeda do seu idioma (no app, a moeda do usuário). A lista inclui
a UF chilena (`CLF`), a unidade corrigida pela inflação em que os concursos de subsídio público do
Chile pedem orçamentos (tomada como CLP 40 000; digite o valor do dia ao converter).

Itens sem preço (os pacotes de fabricantes vêm sem preço) são apontados pelo assistente de projeto
(`bom_unpriced`); a lista de materiais os deixa fora dos totais e o dimensionamento econômico dá a um
tubo sem custo um preço proporcional à seção da parede, calibrado pelos tubos com preço do mesmo
material, para que os diâmetros mantenham a ordem.

## Catálogos de fabricantes (`.oci.cat`)

Quatorze pacotes acompanham o app (259 itens): Hunter, Rain Bird, Toro, Netafim, Rivulis,
NaanDanJain, Jain, Nelson e Senninger (aspersores, microaspersores, gotejadores, fitas e tubos
gotejadores, emissores de pivô, canhões, válvulas e reguladores), Irritec (tubos gotejadores e
gotejadores), Bermad (válvulas hidráulicas), Schneider (bombas centrífugas e submersas 4", com curvas
medidas em 60 Hz) e Amanco Wavin e Multilit (tubos de PVC para irrigação, NBR 14312). Os dados vêm
das tabelas publicadas pelos fabricantes: curvas dos bocais `q = k·H^x` e raios `R = a·H^b`
ajustados por mínimos quadrados às linhas de pressão, vazão e raio (o raio ancorado na pressão de
projeto), constantes, expoentes, diâmetros internos e perdas no gotejador (Kd) como impressos,
faixas de pressão e classes de parede, perdas das válvulas ajustadas às tabelas de perda (ou tiradas
do Kv) e curvas das bombas das tabelas de seleção (eficiência estimada pela potência nominal, já que
as tabelas não a trazem). Cada pacote lista os documentos de origem (`sources`). Os preços ficam em
zero; um pacote com preços informa a moeda (`currency`) e é convertido para a moeda do projeto ao
ser adicionado; uma bomba informa a frequência em que a sua curva foi medida (`hz`), de modo que em
outra rede (Parâmetros de projeto) uma bomba de rotação fixa gira na proporção. Eles ficam em
[catalogs/](../../../catalogs/) como arquivos JSON, um por fabricante, mais um `index.json`.

Cinco pacotes genéricos, sem marca, trazem tubos termoplásticos por norma: `iso1452` (PVC-U pela
ISO 1452-2, PN 6 a 16), `en12201` (PE 100 pela EN 12201-2, SDR 26 a 11), `is4985` (PVC-U pela IS 4985,
classes 1 a 6) e `is4984` (PE 100 e PE 80 pela IS 4984), dn 20 a 315 mm, 415 tubos gerados pelo
`tool/gen_catalogs.dart` a partir das tabelas das normas com cada parede conferida contra a sua
classe, e `astm` (PVC em polegadas pela ASTM D2241, SDR 21 e 26, e D1785, Schedule 40 e 80). Os quatro
primeiros trazem preços de referência com a sua fonte e data (`pricesSource`, `pricesDate`), mostradas
no diálogo *Catálogos de fabricantes…* e para o assistente de IA: a tabela de preços agrícolas de 2024
da região da Sardenha (EUR, fornecido e assentado) para os pacotes ISO e EN e a tabela de preços
2023-24 da Maharashtra Jeevan Pradhikaran (INR, fornecimento) para os pacotes IS, as linhas publicadas
como impressas e os outros tamanhos por um ajuste pela massa por metro. Pelo diálogo
*Catálogos de fabricantes…* você adiciona um pacote ao projeto, importa um arquivo `.oci.cat` ou
carrega um pacote ou um índice inteiro por URL, o que permite a qualquer revenda ou comunidade manter
o próprio repositório. O catálogo do projeto também é exportado nesse formato. O formato completo,
com os campos de cada grupo e as regras de contribuição, está em [catalogs/README.md](../../../catalogs/README.md);
`dart run tool/gen_catalogs.dart` valida os pacotes (ids únicos, curvas plausíveis) e refaz o índice.
