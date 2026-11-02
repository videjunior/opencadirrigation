# Carimbo e documentos técnicos

O que um profissional entrega com um projeto além das plantas: o carimbo com o responsável técnico, o datum das
coordenadas, os documentos que o órgão gestor de recursos hídricos, o cliente, o instalador ou o operador pedem, e as
normas por trás de cada número. O app é uma ferramenta de apoio: um profissional habilitado confere e assina o que
ele produz.

## Carimbo e responsável técnico

Arquivo → *Carimbo e responsável técnico…* (também no menu do celular) preenche o carimbo de todas as folhas e a capa
dos pacotes de documentos: o projeto (propriedade, município/UF), os registros (CAR, o Cadastro Ambiental Rural; o
número da outorga; a etapa, do estudo preliminar ao como construído), a responsabilidade técnica (responsável
técnico, conselho profissional como CREA ou CAU, número de registro e a ART, RRT ou TRT), as folhas (número do
desenho, data de emissão, revisões com o seu autor) e a empresa com o seu logotipo (PNG ou JPEG, reduzido a 512 px;
guardado no arquivo do projeto, fora dos links de compartilhamento). OK é um passo de desfazer e Cancelar devolve
tudo; *Salvar como meu padrão* guarda a empresa, o logotipo, o responsável técnico, o conselho e o registro neste
navegador, e *Preencher com o meu padrão* os preenche em outro projeto.

Assim que algum desses campos é preenchido, as folhas levam o **carimbo profissional**, com 40 mm de altura em vez de
30 mm (a área de desenho fica 10 mm menor): células dispostas como os campos de dados da ISO 7200, com o projeto, os
registros, a responsabilidade técnica, a folha (número do desenho e da folha, escala e papel, data, o sistema de
coordenadas com o seu código EPSG e a origem) e uma coluna para a empresa e o seu logotipo. O quadro de revisões das
folhas junta as revisões do carimbo e as das nuvens de revisão. Sem nada preenchido, as folhas mantêm o carimbo das
versões anteriores.

## Datum das coordenadas

Arquivo → Georreferência… tem um *Datum das coordenadas*: automático pelo local (SIRGAS 2000 na América do Sul e
Central, ETRS89 na Europa, WGS84 nos demais) ou SIRGAS 2000, WGS84, ETRS89 ou NAD83 escolhido. Esses datums coincidem
na precisão de uma planta de projeto (menos de 1 m), então a escolha não muda nenhuma coordenada: ela as nomeia nas
pranchas e nos arquivos `.prj` do shapefile, LandXML, IFC e EPANET. As versões anteriores escreviam SIRGAS 2000
nesses arquivos onde quer que estivesse o projeto; arquivos antigos mantêm as suas coordenadas.

## Quadrícula de coordenadas e folhas do terreno

As opções de plotagem do PDF acrescentam:

- uma **quadrícula de coordenadas** sobre o desenho: UTM (E, N) do fuso do projeto, local (X, Y) sem georreferência,
  geográfica (latitude e longitude em graus, minutos e segundos) ou UTM e geográfica, com os valores nas bordas da
  área de desenho, sem cobrir a seta do norte nem a escala gráfica;
- folhas a mais de **declividade** e de **exposição**: o mapa de declividade por classe, ou a exposição por setor da
  rosa dos ventos, sob o desenho em cinza, com a legenda, a área de cada classe e, na declividade, as classes de cada
  área irrigada. Elas precisam de curvas de nível ou de pontos cotados.

O relatório *Declividade por área irrigada* (na aba Requisitos hídricos, sem precisar de projeto calculado) dá a área
de cada classe de declividade em cada área irrigada, com a declividade média e a máxima.

## Pacotes de documentos

Arquivo → *Exportar pacote de documentos (PDF)…* grava um PDF para cada leitor em vez de todas as tabelas de uma vez:

| Pacote | Para |
|---|---|
| Proposta técnica e comercial | O cliente: o sistema em resumo, o escopo (lista de materiais), o orçamento e as suas condições, o cronograma de execução, a planta e o aceite do cliente |
| Outorga e licenciamento | O órgão gestor e o licenciamento: identificação, os pontos de captação em UTM e em graus, minutos e segundos, a necessidade hídrica, as culturas, a categoria de licenciamento, a declividade e as plantas georreferenciadas com a quadrícula de coordenadas e o mapa de declividade |
| Pasta de instalação | A obra: as folhas por setor com os detalhes construtivos, as pressões a conferir e os materiais por setor |
| Memorial técnico | O processo técnico e os editais: critérios e normas, o dimensionamento hidráulico, as verificações e todas as folhas |
| Operação e manutenção | Quem opera o sistema: o manejo por cultura, as pressões de cada setor e a lavagem das linhas |

Todo pacote tem uma capa com os dados do carimbo (logotipo, empresa, cliente, propriedade, responsável técnico e
registros), um sumário com as páginas, seções numeradas com cabeçalho, as plantas no seu próprio papel e o bloco de
assinatura do responsável técnico. O diálogo escolhe o pacote, o título da capa, o destinatário, o papel das plantas
e o mapa de fundo, e as seções, as dele e as dos outros pacotes; uma seção que precisa dos resultados do cálculo ou
de dados que o projeto não tem diz isso.

## Documentos técnicos

Relatórios → *Documentos técnicos* abre cinco documentos montados a partir do projeto em Dart puro, cada um num
diálogo cujas configurações são um passo de desfazer (Cancelar as devolve) e que exporta em PDF, XLSX, CSV ou
Markdown (para editar o texto); eles também entram nos pacotes de documentos.

- **Quadro de outorga e automonitoramento**: para cada fonte de água, o que um pedido de outorga pede do ponto de
  captação (coordenadas em SIRGAS 2000 em graus, minutos e segundos e em UTM com o código EPSG, o corpo hídrico, a
  finalidade, a área irrigada e as suas culturas, as bombas) e o regime de cada mês pela necessidade bruta das áreas
  (vazão, horas por dia, dias por mês, volume por dia e por mês), com a conferência da capacidade, o mínimo de 300
  m³/ha por mês da Resolução ANA 1.939/2017, o automonitoramento da Resolução ANA 188/2024 e a planilha mensal de
  leituras. Fontes: Lei 9.433/1997, essas duas resoluções e IBGE R.PR 1/2005; rios e aquíferos de domínio estadual
  seguem as regras do órgão estadual.
- **Memorial descritivo e de cálculo**: escrito só a partir do projeto, sem o assistente de IA (o mesmo projeto dá o
  mesmo texto): identificação, objetivo, áreas e culturas, clima e necessidade hídrica, fonte de água, critérios de
  projeto, as fórmulas que o programa usa com os seus símbolos e fontes, os setores, a rede, o bombeamento e a
  energia, a operação, as verificações, os materiais, as suas observações e as referências. Você escreve o objetivo e
  as observações finais.
- **Plano de operação e manutenção**: o manual de entrega com os valores do projeto: a partida (enchimento, lavagem,
  o ensaio de pressão a 1,5 vez a pressão de trabalho dentro da classe dos tubos, o primeiro funcionamento de cada
  setor), a ficha das pressões de cada setor, a lavagem das linhas laterais, a limpeza dos filtros pelo aumento da
  sua perda, a cloração na taxa de injeção de cada turno, a entressafra, o cronograma por componente, o
  automonitoramento e as peças de reposição.
- **Orçamento por composições**: os serviços do cronograma de obra, cada um com a composição da mão de obra e dos
  equipamentos que uma unidade pede (as produtividades do cronograma a custos horários), os materiais da lista pelos
  preços do catálogo, o BDI dos serviços e o BDI do fornecimento de materiais (conferidos com as faixas de referência
  do Acórdão TCU 2622/2013), os tributos sobre o preço e o cronograma físico-financeiro por semana ou por mês. Os
  custos horários iniciais são exemplos: troque-os pelos da tabela de custos de referência da sua região e data (o
  SINAPI, no Brasil).
- **Custo do ciclo de vida**: o projeto atual e cada alternativa salva com os seus resultados comparados pelo
  investimento, reposições, valor residual, energia, água e manutenção ao longo de um horizonte, trazidos a valor
  presente, LCC = I + Repl − Res + E + W + OM&R (NIST Handbook 135), com a taxa de desconto (ou os juros dos
  parâmetros do projeto), o aumento real do preço da energia, o preço da água e a vida útil e a manutenção de cada
  categoria de peças (valores de referência a ajustar aos dados dos fabricantes e à experiência local).

## Normas nos relatórios

Cada tabela de relatório cita, sob o seu título, os critérios que mostra e as normas ou referências que cada um segue
(ABNT NBR, ISO, EN, ASABE/ASAE, AWWA, IEC, FAO, NRCS, CONAMA), nas exportações em PDF, CSV e TXT, para que o leitor
de um memorial ou de um pedido de outorga veja de onde vem cada limite. A verificação do projeto acrescenta
`supply_no_meter` (informação): uma fonte de água sem medidor de vazão na sua linha nem horímetro nas suas bombas,
que o automonitoramento de uma outorga pede.
