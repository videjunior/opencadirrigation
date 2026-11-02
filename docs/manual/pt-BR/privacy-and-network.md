# Armazenamento, privacidade e rede

- **Autosave** no banco de dados do navegador (IndexedDB; o localStorage das versões anteriores é a
  reserva, e as cópias dele passam para lá na abertura), 3 segundos depois da última edição, quando a
  página fica oculta e, como cópia de emergência, quando ela fecha; **projetos recentes** (os 8
  últimos) em Arquivo → Projetos recentes; **versões** (as 10 últimas gravações de cada projeto) em
  Arquivo → Histórico de versões; **recuperação** ao abrir o app, item a item, dos projetos editados e
  não salvos (um arquivo só aberto não é copiado até ser editado). Projetos acima de 256 KB de JSON
  são guardados comprimidos; um projeto ocupa até cerca de 64 MB depois da compressão (cerca de
  3,5 MB onde só há o localStorage). Quando nem assim cabe, as imagens embutidas ficam de fora da
  cópia automática, e o app avisa uma vez por projeto (ou avisa que o projeto não cabe ali: salve-o
  num arquivo). Um armazenamento cheio abre espaço primeiro com as versões mais antigas do mesmo
  projeto, depois com as versões dos outros projetos, depois com os outros projetos já salvos em
  arquivo, nunca com trabalho não salvo em arquivo; quando nada cabe, o aviso fica na barra de status
  (e no celular) até uma cópia caber. A cópia automática é feita em segundo plano: o navegador a
  comprime ao lado do app, então um projeto grande não trava a janela depois de um cálculo nem
  durante a edição. Um aviso do navegador aparece ao fechar a aba com alterações. Arquivo →
  Armazenamento do navegador… diz onde estão as cópias, quanto o site usa, se o navegador as mantém
  quando falta espaço (*Pedir para manter*), as lista e baixa todas num ZIP; essas cópias não são
  backup: limpar os dados do site as apaga, e o Safari faz isso depois de 7 dias sem o site, a menos
  que o app esteja instalado na tela inicial. Um projeto aberto em outra janela deste navegador fica
  fora da recuperação dela, e um link compartilhado, um exemplo da galeria ou uma segunda janela do
  mesmo projeto abrem como cópia com um uid novo.
- **Arquivos**: Salvar grava o arquivo `.oci.json` (o mesmo arquivo de novo onde o navegador deixa o
  app escrever nele, um download nos demais), Salvar como… escolhe outro e Salvar como cópia… guarda
  uma cópia com um uid próprio; Abrir lê do disco. Nada é enviado a servidores.
- **Compartilhar por link** (Arquivo → Compartilhar por link…): o projeto inteiro, comprimido, vai
  dentro do endereço, depois do `#`, parte que o navegador não envia a nenhum servidor; quem abre o
  link recebe uma cópia numa aba nova. Imagens, fotos de comentários, o logotipo do carimbo e os
  resultados ficam de fora (quem recebe calcula de novo); um link com mais de cerca de 60 000
  caracteres pode ser cortado por aplicativos de e-mail e de mensagem, um projeto grande demais para
  um link vai como arquivo, e um link que traz um projeto grande pergunta antes de abrir.
- **Sem rede**: depois que o app rodou num navegador, o service worker dele guarda uma cópia do app
  (cerca de 20 MB, uma vez por versão, mais o pacote de idioma e as fontes do PDF que uma abertura
  usa) e a próxima abertura, do app instalado ou do site, funciona sem rede. Mapas base, elevação e
  clima online, catálogos carregados por URL e o assistente de IA continuam precisando dela. Uma
  versão nova é baixada em segundo plano; o app então oferece recarregar nela (o trabalho não salvo
  vai para o autossalvamento), ou ela é usada a partir da abertura seguinte. Os blocos e pontos da
  elevação online e as séries de clima baixados ficam guardados no aparelho (IndexedDB no navegador,
  arquivos no desktop), até 200 MB, saindo primeiro os mais antigos, então refazer o terreno ou o
  clima dispensa a rede; Arquivo → Dados baixados guardados… os mostra por tipo e os apaga.
- **Acesso à internet**, para o que você pede: elevação online (Terrain Tiles na AWS, Open-Meteo,
  OpenTopoData nos builds para desktop), clima do local (NASA POWER por padrão, histórico
  meteorológico do Open-Meteo), mapas base (OpenStreetMap ou o servidor do mapa de ruas que você
  definir, OpenTopoMap, CARTO, Esri, Google Maps com a sua própria chave ou uma URL XYZ ou WMS
  personalizada; os blocos de satélite também para Contornar pela imagem), catálogos carregados por
  URL e o assistente de IA. Os
  pedidos de elevação e de clima levam as coordenadas do local, nada do projeto. A chave do Google
  Maps fica no armazenamento do navegador, que qualquer script do site poderia ler, e é enviada
  apenas ao Google (restrinja-a ao site no console do Google Cloud); onde o servidor não tem imagem no zoom
  atual, o app amplia o tile mais próximo em vez de mostrar um aviso de "dados indisponíveis". As
  fontes de todas as escritas e símbolos (chinês, japonês, árabe, escritas indianas, emoji, setas)
  vêm do próprio site, nunca de um serviço de fontes (veja [Idiomas e site](languages-and-site.md)).
- **Assistente de IA** (opcional, [assistente de IA](ai-assistant.md)): o único recurso que envia
  dados do projeto a terceiros, e só por ação sua. Nada sai antes de você enviar uma mensagem; então
  os pedidos vão só para a empresa do modelo que você escolheu, a Anthropic (`api.anthropic.com`) ou
  a OpenAI (`api.openai.com`, com `store: false`), com a sua chave dela: a sua mensagem, os arquivos
  anexados, os dados do projeto que você marcou (um texto compacto montado das tabelas dos
  relatórios e das mensagens do projeto, com a posição do local arredondada a cerca de um
  quilômetro; a vista *Dados enviados* mostra o texto exato da próxima mensagem), as mensagens
  anteriores da conversa e, enquanto o modelo trabalha, os resultados das ferramentas que ele chama:
  tabelas, itens e imagens do desenho sobre o mapa base, inclusive a imagem de satélite (valem os
  termos do provedor das imagens, Esri ou Google, para o que sai; as imagens baixam os seus tiles
  como a tela faz, sem perguntar). Uma busca do local por endereço envia o endereço ao Nominatim do
  OpenStreetMap (`nominatim.openstreetmap.org`), com a sua aprovação, a não ser que as alterações
  sejam aplicadas automaticamente. Cada chave fica na memória enquanto a página está aberta; com
  *Lembrar a chave neste dispositivo* ela é guardada no armazenamento do navegador, que qualquer
  script do site poderia ler (as estatísticas de visita do site nunca rodam numa página em que o app
  roda). As chaves nunca entram no arquivo do projeto, no autosave, nos links de compartilhamento
  nem nas exportações, e cada uma só vai para a sua própria empresa. O ditado por voz envia o som da
  sua voz ao serviço de voz do navegador (o Chrome usa os servidores do Google, o Edge os da
  Microsoft e o Safari os da Apple), que devolve o texto; o app não grava nem guarda o áudio, e o
  texto só chega à IA quando você o envia. Uma foto fixada com `add_photo_comment` guarda uma cópia
  pequena (cerca de 480 pixels) no arquivo do projeto, fora dos links de compartilhamento; o modelo
  lê só o tamanho dela. As notas de IA fazem parte do arquivo do projeto, então vão com ele e com os
  links de compartilhamento. As conversas ficam no armazenamento deste navegador (IndexedDB), por
  projeto, com as imagens e os arquivos pequenos anexados, mas nunca as chaves, de modo que
  recarregar a página ou abrir o projeto de novo as traz de volta; as 24 salvas mais recentemente
  são guardadas (um projeto pode guardar várias), e *Guardar as conversas neste navegador*, nas
  configurações do assistente, desliga isso e as apaga. Uma conversa exportada num arquivo deixa de
  fora a chave e as fotos que você anexou. O aviso quando o app está em segundo plano faz piscar o
  título da aba e, se você permitir, mostra notificações do sistema; nada dele sai da página. O que
  cada empresa faz com os pedidos é regido pelo seu acordo com ela.
- **Estatística de visitas**: as páginas de opencadirrigation.com perguntam uma vez se podem contar
  as visitas e só carregam o Google Analytics 4 depois de *Aceitar* (Consent Mode v2: tudo negado
  por padrão, só a estatística liberada), nunca numa página em que o app roda, de modo que ele não
  alcança projetos nem chaves; *Recusar*, também depois em *Preferências de cookies* no rodapé das
  páginas, apaga os cookies dele. O ID de medição é definido quando as páginas são geradas
  (`OCI_ANALYTICS_ID`, vazio para nenhum). A política de privacidade (`/privacy/`) e os termos de uso
  (`/terms/`) são gerados com as páginas, e Ajuda → Sobre leva a eles no idioma da interface.
- **Idioma e preferências** (idioma escolhido, tema, tamanho e contraste da interface, as
  configurações de desenho e de snap, catálogo padrão, os padrões de projetos novos e do carimbo,
  onde o tutorial parou, as configurações do assistente) ficam nas preferências do navegador.
