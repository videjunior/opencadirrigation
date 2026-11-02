# Limitações conhecidas e roteiro

- **Redes malhadas**: o LP dimensiona malhas por caminhos em árvore (aproximação) e é resolvido de
  novo com as vazões dos novos diâmetros até eles se firmarem; a análise final confere, e o método
  guloso é a alternativa segura.
- **Solver de rede**: emissores autocompensantes em redes grosseiramente subdimensionadas (vazões
  muitas vezes maiores do que os tubos comportam) ainda podem não convergir; o projeto então
  informa `not_converged` em vez de números.
- **Transientes**: a análise cobre a linha principal de cada turno, com as zonas vistas dela como
  orifícios nas suas válvulas; o atrito é quase-permanente (um fator constante por tubo);
  reservatórios hidropneumáticos são modelados pelo motor, mas ainda não podem ser colocados num
  projeto.
- **Simulação de 24 horas**: um projeto não tem reservatório cujo nível varie ao longo do dia (as
  fontes mantêm o nível); reservatórios, padrões e controles por nível existem na simulação de
  período estendido do motor ([docs/API.pt-BR.md](../../../docs/API.pt-BR.md)).
- **Elétrica**: o cálculo liga as válvulas da forma convencional (um fio de estação por válvula e um
  comum compartilhado) com solenoides de 24 V CA; o dimensionamento de dois fios (decodificadores)
  das Rotas automáticas de fios é uma análise à parte, cujos decodificadores e cabo não entram na
  lista de materiais.
- **DWG e DXF**: o leitor cobre as entidades típicas de uma planta (linhas, polilinhas, círculos,
  arcos, elipses, splines, hachuras, sólidos, chamadas, pontos, textos, blocos e cotas), com R13/R14
  lidos em parte; os escritores gravam só R2000 (DWG com índices de cor; cores verdadeiras no
  DXF), e as imagens saem como a sua moldura, sem o raster.
- **Plantas em PDF**: degradês, preenchimentos com padrão (desenhados em cinza), grupos de
  transparência, anotações e glifos Type 3 não são interpretados; o recorte é aproximado por
  retângulos; áreas preenchidas entram como contornos; arquivos criptografados e imagens JPEG 2000
  ou JBIG2 ficam de fora; o trabalho por página tem um teto, e uma página truncada avisa.
- **Outros arquivos**: nuvens LAZ comprimidas, DGN V8 e BigTIFF são recusados pelo nome; rasters
  acima de 100 milhões de pixels são recusados; um terreno acima de 12 000 amostras é triangulado a
  partir de um subconjunto uniforme.
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
- **Cópia automática no navegador**: cerca de 3,5 MB por projeto depois da compressão; projetos
  maiores ficam só no arquivo (o app avisa uma vez).
- **Colaboração**: não há edição simultânea; projetos são compartilhados pelo arquivo `.oci.json`
  ou por um link, que deixa de fora imagens e resultados e é recusado quando o projeto é grande
  demais.
- **Desempenho**: projetos com centenas de fitas por zona levam alguns segundos por zona; a etapa de
  lavagem é a mais pesada.
- **Abertura sem rede**: testada em navegadores baseados no Chromium; mapas base, elevação e clima
  online, catálogos por URL e o assistente de IA precisam da rede.
- **Celular nativo**: as pastas `android/` e `ios/` são os modelos do Flutter e não são compiladas
  nem testadas; celulares e tablets usam o app web.
- **Assistente de IA**: precisa da rede e de uma conta com crédito na API da Anthropic ou da OpenAI
  (o Claude Fable 5.1 também de retenção de dados de 30 dias); no navegador uma chave da OpenAI
  recusada aparece como falha de rede, porque as respostas de erro da OpenAI não trazem cabeçalho
  CORS; as imagens não pedem aprovação, embora baixem tiles do mapa base; posições lidas de imagens
  são aproximadas; as análises que ele roda (transientes, simulação de 24 horas e afins) rodam na
  thread da interface; as conversas não vão no arquivo do projeto nem nos links de compartilhamento,
  mas ficam neste navegador (as 12 mais recentes de cada projeto, com as imagens e os anexos
  pequenos) até que *Guardar as conversas neste navegador* seja desligado, o que também as apaga: num
  computador compartilhado, desligue-o ou limpe os dados do site. Ele foi testado contra
  imitações programadas das duas APIs, não contra os serviços reais. As respostas podem conter
  erros, como as de qualquer modelo: as alterações passam pela aprovação, pelo desfazer e pelo
  voltar a um ponto do [assistente de IA](ai-assistant.md), e o projeto deve ser conferido.

Roteiro sugerido: sistemas de dois fios na lista de materiais do cálculo; reservatórios
hidropneumáticos e de armazenamento colocados num projeto; catálogos adicionais da comunidade;
testes de navegador da abertura sem rede no Firefox e no Safari; testes de navegador automatizados
para a troca de idioma em tempo de execução.
