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
- **Fileiras da imagem**: fileiras retas, igualmente espaçadas e vistas com pelo menos uns três
  pixels da imagem por espaçamento (fileiras a menos de cerca de 1–2 m não aparecem na maior parte
  das imagens gratuitas); fileiras em nível que curvam dão uma direção média; qual faixa é a cultura
  é decidido pela cor e pode pedir *Fileiras na outra faixa*; o espaçamento entre plantas raramente
  aparece a 0,3–0,6 m por pixel e fica então desconhecido; sombras contam como copa. Roda na página
  com pausas e um botão Parar, não num worker, e foi conferida nos testes e em imagens reais fora do
  app, não num navegador de verdade.
- **Risco climático ao longo dos anos**: células de reanálise de cerca de 50 km suavizam os extremos
  locais; só o primeiro ciclo de cultivo de uma área é avaliado; o resumo guardado no projeto não
  acompanha mudanças posteriores do projeto (refaça a análise); a análise roda na página, então um
  projeto com muitas áreas pode prendê-la por um ou dois segundos; a autocorrelação não é removida do
  teste de tendência. Um download completo do serviço real da NASA POWER pelo app e o diálogo num
  navegador de verdade não foram experimentados (duas respostas reais são lidas nos testes).
- **Previsão de irrigação**: a radiação dos dias do MET Norway vem da amplitude térmica (eq. 50 da
  FAO-56, kRs 0,16 em todo lugar; 0,19 seria o de locais costeiros), conferida contra a ETo do
  Open-Meteo em só cinco dias de um local; os dias são dias solares locais, que podem diferir uma ou
  duas horas do relógio; a previsão não é salva no projeto nem no relatório principal. Os navegadores
  chamam o MET Norway diretamente, o que os termos dele permitem para sites de pouco volume; um
  tráfego muito maior pediria um proxy. O diálogo e a exportação em PDF não foram experimentados num
  navegador de verdade.
- **Programa na planta**: o regime permanente de cada turno, sem transientes nas partidas e paradas;
  turnos sobrepostos são somados, não resolvidos juntos; o nível do reservatório vem da continuidade
  do volume ao longo do programa, não da simulação de 24 horas; o calendário usa os tempos de um mês,
  hora flutuante e nenhum alarme; um período maior que 28 dias é cortado. Não experimentado num
  navegador de verdade.
- **Boletim de qualidade do projeto**: pesos iguais, parcelas de atendimento lineares e contagens de
  tudo ou nada; as notas comparam projetos e não são uma certificação; as faixas de q_var são faixas
  de trabalho do programa (veja [Cálculo e dimensionamento](calculation.md#boletim-de-qualidade-do-projeto));
  as exportações do diálogo não foram experimentadas num navegador de verdade.
- **Curvas de uma imagem**: só calibração afim (uma foto tirada de lado é lida de forma aproximada);
  uma curva de cada tipo por imagem; a potência é tomada como potência no eixo (P2); colar uma
  imagem no Safari e a roda e a pinça num navegador de verdade não foram experimentadas.
- **Servidor MCP**: testado no macOS (as regras de caminho do Windows estão escritas, mas não
  testadas); `set_project` confere as chaves, os tipos e as opções das configurações, mas não as
  faixas (a verificação do projeto aponta configurações impossíveis); exportações e relatórios não
  são gravados de forma atômica, então uma chamada cancelada no meio pode deixar um arquivo
  incompleto; um hard link dentro da raiz, ou um link trocado entre a verificação e o uso, não é
  percebido; o pacote do motor vai sem os projetos de exemplo.
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
  online não guardados no aparelho, a previsão do tempo, catálogos por URL e o assistente de IA
  precisam da rede. Os links de compartilhamento (primeira visita, visita de volta, colados no app
  aberto, sem rede) foram conferidos por esse teste de fumaça só no Chromium antes do lançamento; o
  WebKit e o Firefox o rodam na CI.
- **Documentos técnicos**: o quadro de outorga e o orçamento por composições seguem a prática
  brasileira (resoluções da ANA, as faixas de BDI do Acórdão TCU 2622/2013; rios e aquíferos de
  domínio estadual seguem o órgão estadual); os custos horários iniciais do orçamento e a vida útil e a
  manutenção das peças no custo do ciclo de vida são valores de referência a trocar pelos locais.
- **Celular nativo**: as pastas `android/` e `ios/` são os modelos do Flutter e não são compiladas
  nem testadas; celulares e tablets usam o app web.
- **Assistente de IA**: precisa da rede e de uma conta com crédito na API de uma das seis empresas
  (o Claude Fable 5.2 também de retenção de dados de 30 dias; os níveis gratuitos do Google e os
  modelos gratuitos da OpenRouter têm os limites das suas empresas); no navegador uma chave da OpenAI
  recusada aparece como falha de rede, porque as respostas de erro da OpenAI não trazem cabeçalho
  CORS, e a página não consegue ler o identificador do pedido e os limites de uso da Meta nem as
  esperas da OpenRouter (o app de desktop consegue); um navegador que siga ao pé da letra as regras de
  CORS para o cabeçalho de autorização poderia recusar os pedidos à Meta, o que só foi conferido no
  Chrome; os modelos do Google, da xAI, da Meta e da OpenRouter não são resumidos quando uma conversa
  fica longa; as imagens não pedem aprovação, embora baixem tiles do mapa base; posições lidas de imagens
  são aproximadas; as análises que ele roda (transientes, simulação de 24 horas e afins) rodam na
  thread da interface; as conversas não vão no arquivo do projeto nem nos links de compartilhamento,
  mas ficam neste navegador (as 24 salvas mais recentemente, com as imagens e os anexos
  pequenos) até que *Guardar as conversas neste navegador* seja desligado, o que também as apaga: num
  computador compartilhado, desligue-o ou limpe os dados do site. Ele foi testado contra
  imitações programadas das seis APIs, não contra os serviços reais: os quatro clientes
  acrescentados na 1.7.0 (Google, xAI, Meta, OpenRouter) foram escritos a partir da documentação de
  cada empresa de 2026-11-10 e nunca rodaram com uma chave de verdade, então um formato que uma
  empresa mudou ou documentou de modo vago ainda pode falhar. As respostas podem conter erros, como
  as de qualquer modelo, e uma segunda opinião é a visão de outro modelo, não uma verificação: as
  alterações passam pela aprovação, pelo desfazer e pelo
  voltar a um ponto do [assistente de IA](ai-assistant.md), e o projeto deve ser conferido.

Roteiro sugerido: reservatórios no meio da rede de um projeto; catálogos adicionais da comunidade; a
abertura sem rede conferida no próprio Safari; testes de navegador automatizados para a troca de
idioma em tempo de execução; os quatro clientes novos de IA experimentados contra os serviços reais;
uma calibração por quatro cantos (perspectiva) de gráficos fotografados; as correções automáticas, os
cenários e os dados on-line como ferramentas do servidor MCP.
