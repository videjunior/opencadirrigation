# Limitações conhecidas e roteiro

- **Redes malhadas**: o LP leva o balanço de energia de cada anel para as vazões com que dimensiona e
  é resolvido de novo com as vazões dos novos diâmetros até elas se acomodarem; quando não se
  acomodam, uma nota diz que o resultado é uma aproximação; a análise final confere, e o método guloso
  é a alternativa segura.
- **Solver de rede**: emissores autocompensantes em redes grosseiramente subdimensionadas (vazões
  muitas vezes maiores do que os tubos comportam) ainda podem não convergir; o projeto então
  informa `not_converged` em vez de números.
- **Transientes**: a análise cobre a linha principal de cada turno, com as zonas vistas dela como
  orifícios nas suas válvulas; o atrito é quase-permanente (um fator constante por tubo); os vasos de
  ar vão só nas junções da linha principal.
- **Simulação de 24 horas**: o único nível que varia ao longo do dia é o do reservatório ou açude
  atrás de uma fonte de água; reservatórios no meio da rede, padrões e controles por nível existem na
  simulação de período estendido do motor ([docs/API.pt-BR.md](../../../docs/API.pt-BR.md)), mas não
  num projeto.
- **Elétrica**: o cálculo liga as válvulas da forma convencional (um fio de estação por válvula e um
  comum compartilhado) com solenoides de 24 V CA, ou, com Zona → Sistema de dois fios ligado, como um
  sistema de dois fios (decodificadores) cujos decodificadores e cabo substituem os fios das estações
  na lista de materiais. A elétrica da casa de bombas segue a NBR 5410 (como a IEC 60364-5-52) e a
  IEC 60909 com fatores de potência típicos dos motores e impedâncias de curto típicas dos
  transformadores.
- **DWG e DXF**: o leitor cobre as entidades típicas de uma planta (linhas, polilinhas, círculos,
  arcos, elipses, splines, hachuras, sólidos, chamadas, pontos, textos, blocos e cotas), com R13/R14
  lidos em parte; os escritores gravam só R2000 (DWG com índices de cor; cores verdadeiras no
  DXF), e as imagens saem como a sua moldura, sem o raster.
- **Plantas em PDF**: degradês, preenchimentos com padrão (desenhados em cinza), grupos de
  transparência, anotações e glifos Type 3 não são interpretados; o recorte é aproximado por
  retângulos; áreas preenchidas entram como contornos; arquivos criptografados e imagens JPEG 2000
  ou JBIG2 ficam de fora; o trabalho por página tem um teto, e uma página truncada avisa.
- **Outros arquivos**: nuvens LAZ comprimidas e DGN V8 são recusados pelo nome; JPG, PNG e outras
  imagens acima de 100 milhões de pixels são recusadas (os rasters TIFF, inclusive BigTIFF e GeoTIFF
  otimizado para a nuvem, são lidos por blocos e reduzidos, até 4 bilhões de pixels); acima de
  40 000 amostras o TIN mantém o levantamento e rarefaz o modelo de elevação baixado.
- **Datums**: SAD 69 e Córrego Alegre são deslocados por translações de três parâmetros (precisão
  de alguns metros); não se aplica uma transformação por grade.
- **Densograma**: um único perfil de aspersão para todas as cabeças sem perfil medido (escolhido no
  diálogo: sprays ficam mais perto do uniforme, aspersores de impacto de bocal único do
  triangular); o vento é um deslocamento de primeira ordem do padrão sem vento, que não substitui
  medições em dia de vento.
- **Agronomia e modelos de campo**: os valores de solo são os típicos da classe textural; a fórmula
  do bulbo molhado vem de dois solos e dois gotejadores e extrapola fora deles; o braço de canto
  supõe terreno plano, braço rígido e caminho guia convexo; a irrigação por superfície usa o
  balanço de volume, não um modelo hidrodinâmico.
- **Detecção de vegetação**: processamento simples das cores e da textura de uma imagem: gramados
  secos, sombra forte ou telhados verdes podem ser mal interpretados, então os contornos precisam
  de conferência; valem os termos de uso das imagens.
- **Cópia automática no navegador**: cerca de 64 MB por projeto depois da compressão no IndexedDB
  (cerca de 3,5 MB onde só há o localStorage); projetos maiores ficam só no arquivo (o app avisa uma
  vez). As cópias ficam neste navegador, neste aparelho, e não são backup.
- **Colaboração**: não há edição simultânea; projetos são compartilhados pelo arquivo `.oci.json`
  ou por um link, que deixa de fora imagens e resultados e é recusado quando o projeto é grande
  demais; uma cópia revisada é comparada com Arquivo → Comparar com… e os comentários dela são
  trazidos com Arquivo → Trazer comentários de uma cópia.
- **Desempenho**: projetos com centenas de fitas por zona levam alguns segundos por zona; a etapa de
  lavagem é a mais pesada.
- **Abertura sem rede**: conferida pelo teste de fumaça de ponta a ponta no Chromium e, onde o build
  do navegador consegue rodar a verificação, nos builds de WebKit e Firefox do Playwright (uma
  verificação que um build não consegue rodar é informada como pulada); mapas base, elevação e clima
  online não guardados no aparelho, catálogos por URL e o assistente de IA precisam da rede.
- **Documentos técnicos**: o quadro de outorga e o orçamento por composições seguem a prática
  brasileira (resoluções da ANA, as faixas de BDI do Acórdão TCU 2622/2013; rios e aquíferos de
  domínio estadual seguem o órgão estadual); os custos horários iniciais do orçamento e a vida útil e a
  manutenção das peças no custo do ciclo de vida são valores de referência a trocar pelos locais.
- **Celular nativo**: as pastas `android/` e `ios/` são os modelos do Flutter e não são compiladas
  nem testadas; celulares e tablets usam o app web.
- **Assistente de IA**: precisa da rede e de uma conta com crédito na API da Anthropic ou da OpenAI
  (o Claude Fable 5.1 também de retenção de dados de 30 dias); no navegador uma chave da OpenAI
  recusada aparece como falha de rede, porque as respostas de erro da OpenAI não trazem cabeçalho
  CORS; as imagens não pedem aprovação, embora baixem tiles do mapa base; posições lidas de imagens
  são aproximadas; as análises que ele roda (transientes, simulação de 24 horas e afins) rodam na
  thread da interface; as conversas não vão no arquivo do projeto nem nos links de compartilhamento,
  mas ficam neste navegador (as 24 salvas mais recentemente, com as imagens e os anexos
  pequenos) até que *Guardar as conversas neste navegador* seja desligado, o que também as apaga: num
  computador compartilhado, desligue-o ou limpe os dados do site. Ele foi testado contra
  imitações programadas das duas APIs, não contra os serviços reais. As respostas podem conter
  erros, como as de qualquer modelo: as alterações passam pela aprovação, pelo desfazer e pelo
  voltar a um ponto do [assistente de IA](ai-assistant.md), e o projeto deve ser conferido.

Roteiro sugerido: reservatórios no meio da rede de um projeto; catálogos adicionais da comunidade; a
abertura sem rede conferida no próprio Safari; testes de navegador automatizados para a troca de
idioma em tempo de execução.
