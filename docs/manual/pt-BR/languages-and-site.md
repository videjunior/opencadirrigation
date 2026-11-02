# Idiomas e site

A interface está em **20 idiomas**, os mais falados do mundo. Português, inglês e espanhol vêm
compilados no app; chinês (`zh`), hindi (`hi`), árabe (`ar`), francês (`fr`), bengali (`bn`), russo
(`ru`), urdu (`ur`), indonésio (`id`), alemão (`de`), japonês (`ja`), marati (`mr`), vietnamita
(`vi`), télugo (`te`), hauçá (`ha`), turco (`tr`), panjabi (`pa`, escrita gurmukhi) e suaíli (`sw`)
são pacotes de idioma em `assets/i18n/<código>.json`, baixados só quando o idioma é escolhido (a
interface mostra inglês até o pacote chegar, uma fração de segundo). Cada pacote traduz toda a tabela
de textos, o tutorial interativo e os nomes do catálogo padrão; o worker de projeto recebe o pacote
junto com o pedido, então relatórios e plotagens também saem no idioma escolhido. O app abre no
primeiro idioma da lista de idiomas preferidos do sistema (do navegador ou do sistema operacional)
que ele fala, e em inglês quando nenhum deles é falado; a troca em Ver → Idioma (cada idioma com o
próprio nome) fica salva. As páginas de idioma (`/pt/`, `/de/`, …) e o parâmetro `?lang=` valem só para a visita.
O atributo `lang` do documento acompanha o idioma do app (`pt-BR`, `zh-CN`, senão o código). Em
árabe e urdu a interface é montada da direita para a esquerda. Os PDFs imprimem todas essas
escritas ([Relatórios, plotagem e exportação](reports-and-export.md)): antes de gravar um PDF, as fontes Noto de que os seus textos precisam são
carregadas uma vez por sessão. Os projetos de exemplo distribuídos existem nos 20 idiomas
(`examples/<código>/`).

Um pacote é um JSON simples com três seções: `strings` (chave → texto), `tutorial` e `catalog`
(texto de origem em inglês → texto). Tradutores podem revisá-lo sem tocar no código, e falantes
nativos o revisam numa planilha ([abaixo](#revisão-das-traduções-por-falantes-nativos));
`test/core/i18n_packs_test.dart` verifica que cada pacote cobre todas as chaves com os mesmos
marcadores.

O site é gerado por `dart run tool/gen_site.dart` a partir de `tool/site.dart`: `web/index.html`
(inglês, a página de quem chega sem idioma escolhido), um `web/<código>/index.html` para cada um
dos outros 19 idiomas da interface (`web/pt/`, `web/es/`, `web/de/`, `web/zh/`, …; a lista segue
`supportedLanguages`, então um idioma novo no app precisa da sua página), um redirecionamento em
`web/en/index.html` para o endereço que o inglês tinha antes, `web/sitemap.xml`, `web/404.html`
(no idioma do navegador quando o site o tem), a política de privacidade e os termos de uso de cada
idioma (`web/privacy/`, `web/<código>/privacy/`, e `terms/` do mesmo jeito; escritos em português,
inglês e espanhol, em inglês nos demais até serem traduzidos, e então fora da indexação), um
manifest por idioma (`web/manifest.json`, `web/<código>/manifest.json`: a mesma identidade do app,
endereço de início, nomes e atalhos naquele idioma, uma captura larga e uma estreita), `web/site.js`
(o único script das páginas: inicia o app quando ele é pedido e pergunta o consentimento das
estatísticas) e a configuração de hospedagem `hosting/firebase.json` (veja `hosting/README.md`). Os textos das páginas ficam em `tool/site.dart`
(português, inglês, espanhol) e em `tool/site/<código>.dart` (os demais, com a galeria de exemplos
tirada dos pacotes de idioma); as páginas em árabe e urdu são da direita para a esquerda. Como o
Flutter desenha em canvas, cada página traz o conteúdo em HTML real (título, recursos, exemplos,
perguntas frequentes), com canônica própria, `hreflang` entre todas as versões (também os genéricos
`pt` e `zh` ao lado de `pt-BR` e `zh-CN`), uma Content Security Policy (scripts só do site,
WebAssembly para o CanvasKit, nenhum script inline, nenhum plugin nem frame), Open Graph (com uma imagem de compartilhamento na escrita da própria página,
`web/og/og-image-<código>.jpg`, gerada a partir da página por `node tool/og/render_og.js`; o inglês mantém
`web/og-image.png`) e JSON-LD
(aplicativo, perguntas frequentes, como funciona e galeria de exemplos, no idioma da página, com o
assunto ligado à Wikipédia/Wikidata). O teste `test/web_metadata_test.dart` falha quando os arquivos
gerados divergem do template.

Esse HTML é tudo o que uma primeira visita baixa (e o que buscadores e o PageSpeed medem): o app,
de vários megabytes, só é baixado quando o visitante o abre (os botões e os links de exemplo da
página o iniciam ali mesmo), chega por um endereço do app (`?example=`, `?tutorial=`, `?design=`, `?ai=`,
`?lang=`, o `?source=pwa` do app instalado) ou já o usou naquele navegador (qualquer chave
`opencadirrigation.` no `localStorage`); a página fica então escondida sob o app.
`web/flutter_bootstrap.js` é o carregador do Flutter sem o service worker obsoleto do Flutter, e
`tool/build_web.sh` tira a referência ao `flutter.js.map` que o build não gera e compila com
`--no-web-resources-cdn`: o CanvasKit e a fonte Roboto vêm do próprio site, não da CDN do Google. O
logo do topo é WebP em três larguras (`web/brand/logo-horizontal-{520,780,1040}.webp`, feitos de
`logo-horizontal.png`), com o endereço versionado por um hash do arquivo. O site é servido pelo
Firebase Hosting a partir de uma pasta de publicação fora deste repositório (`public/`, cópia de
`build/web`, ao lado do `firebase.json`); a configuração é versionada em `hosting/firebase.json`,
gerada com as páginas (`hosting/README.md` diz como aplicá-la). Ela não tem rewrite genérico, então
um endereço inexistente recebe o `404.html` com status 404 em vez da página do app (o que fazia o
PageSpeed ver `/.well-known/ai-catalog.json` como um catálogo de IA quebrado); todo arquivo recebe
`nosniff`, `SAMEORIGIN`, uma `Referrer-Policy` e uma `Permissions-Policy` limitada à posição do
aparelho e ao microfone; as páginas, os manifests e todo arquivo do app cujo nome não muda de build
para build (`main.dart.js`, o worker, `flutter_bootstrap.js`, `sw.js`, `offline.js`, `site.js`,
`assets/**`, `canvaskit/**`) vão com `no-cache`, as imagens de `brand/`, `icons/`, `screenshots/` e
da raiz ficam 30 dias em cache, e `/en/` responde com um 301 para `/`.

**Abertura sem rede.** Quando o primeiro quadro já está na tela e o navegador está ocioso,
`flutter_bootstrap.js` carrega `web/offline.js`, que registra o service worker do próprio app,
`web/sw.js`; assim a primeira visita nunca fica mais lenta por causa dele. `tool/build_web.sh`
termina com `dart run tool/gen_sw.dart`, que grava no `sw.js` do build o nome do build (versão,
commit git, data e um hash dos arquivos) e os arquivos de que uma abertura pode precisar, com seus
SHA-256: a página raiz, o bootstrap, `main.dart.js`, o worker de cálculo, `site.js`, o manifest e os
ícones, os assets do Flutter, o logo e o CanvasKit (só a variante do navegador), cerca de 17 MB
descompactados. Os pacotes de idioma, as fontes do PDF e a lista de licenças também vão listados com
o hash, mas só são guardados quando uma abertura os usa, e um build novo leva adiante os que o
navegador já guardou, baixando a versão nova quando mudaram. Na instalação o worker
preenche um cache por build (`oci-shell-<build>`): os arquivos que não mudaram desde o build
anterior são copiados do cache dele, os outros são baixados passando por cima do cache HTTP e
conferidos pelo hash. Ele responde primeiro pelo cache e revalida a página de abertura depois do
primeiro quadro; guarda as fontes de fallback que o motor baixa de fonts.gstatic.com; tiles de mapa,
elevação, clima e analytics vão direto para a rede. Um build novo é instalado em segundo plano; o
`offline.js` avisa o app, que oferece recarregar nele (*Há uma versão nova do OpenCADIrrigation
pronta*, depois de avisar do trabalho não salvo, que vai para o autossalvamento), e senão ele é
assumido na próxima abertura. Uma página já aberta continua com o build com que abriu (as outras
páginas abertas mantêm o delas quando uma recarrega), uma página aberta por dias procura um build
novo a cada hora e quando volta à tela, e o cache de um build é apagado quando nenhuma página o usa
mais. Um
`sw.js` que não foi preenchido (`flutter run`, um `flutter build web` simples) só remove a si mesmo
e os seus caches.

O gerador também escreve o que buscadores e assistentes de IA leem além das páginas:
`web/robots.txt` (tudo liberado, com os robôs de busca e de IA nomeados: GPTBot, OAI-SearchBot,
ClaudeBot, PerplexityBot, Google-Extended, Applebot-Extended, CCBot, bingbot e outros),
`web/llms.txt` (o resumo do [llmstxt.org](https://llmstxt.org): o que é o app, fatos principais e
links para a página de cada idioma e cada exemplo) e `web/llms-full.txt` (a referência completa em
Markdown: recursos, fluxo de projeto, métodos hidráulicos, dimensionamento, catálogos, formatos,
links diretos, limitações, perguntas frequentes; as seções técnicas ficam em `tool/site/llms.dart` e
seguem o manual em inglês), `web/humans.txt` e a chave IndexNow `web/<chave>.txt`. Depois de publicar,
`dart run tool/indexnow.dart` pede ao Bing, ao Yandex e aos outros buscadores do IndexNow que
rastreiem as páginas de novo (o índice do Bing também responde ao Copilot e à busca do ChatGPT);
`--dry-run` mostra a requisição sem enviá-la.

## Revisão das traduções por falantes nativos

Os testes conferem em cada pacote as chaves que faltam, os marcadores e o glossário, mas só um
falante nativo sabe dizer se um texto soa bem. `tool/i18n_review.dart` transforma um idioma numa
planilha que o revisor preenche sem abrir JSON nem código, e traz o arquivo revisado de volta para o
pacote:

```bash
dart run tool/i18n_review.dart export ha                  # build/i18n_review/i18n-review-ha.csv
dart run tool/i18n_review.dart export all --format xlsx   # todos os idiomas menos o inglês, em XLSX
dart run tool/i18n_review.dart import i18n-review-ha.xlsx --dry-run   # o que mudaria, sem gravar nada
dart run tool/i18n_review.dart import i18n-review-ha.xlsx             # grava assets/i18n/ha.json
```

**O arquivo.** Uma linha por texto do idioma: a tabela de textos, o tutorial e os nomes do catálogo
padrão (português e espanhol vêm das tabelas compiladas; o inglês é a origem e não é exportado). As
colunas são `status`, `section` (`strings`, `tutorial`, `catalog`), `key` (a chave do texto; para o
tutorial e o catálogo, o próprio texto em inglês), `english`, `current (<código>)` (a tradução que o
idioma tem hoje), `review` e `comment` (vazias, para o revisor), `notes`, `context` (onde o texto
aparece: os arquivos da interface que mostram a chave, o tutorial, o catálogo) e `order` (o lugar do
texto no programa: ordenar por ela devolve cada texto para junto dos vizinhos). As linhas vêm das
mais urgentes para as menos urgentes, pelo `status`: `missing` (ainda sem tradução: o app mostra
inglês), `fix` (a tradução quebra uma regra: um marcador perdido, uma palavra que o glossário evita,
um nome que deve ficar como em inglês), `provisional` (o texto em inglês mudou e o pacote espera uma
tradução nova), `same-as-english` (deixado em inglês onde se espera uma tradução), `translated`,
`may-stay-english` (uma sigla, um nome de método ou de arquivo que o glossário permite em inglês) e
`keep-english` (nomes, símbolos e fórmulas, iguais em todos os idiomas). As notas dizem o que
`tool/i18n/glossary.json` pede daquele texto: por que ele pode ou deve ficar em inglês, o termo a
usar para um conceito que o texto em inglês cita e as palavras a evitar (*Glossary: “emitter” is
“Auslass”, never “Emitter”…*), os marcadores a manter (`{n}`, `{name}`…) e, para um texto do
tutorial ou do catálogo cujo inglês mudou, a tradução anterior como ponto de partida. O CSV segue a
RFC 4180, em UTF-8 com a marca de ordem de bytes (BOM), para que os programas de planilha leiam
todas as escritas. O XLSX tem as mesmas colunas na primeira aba e as instruções na segunda; é a
escolha mais segura, porque um programa de planilha pode tomar por fórmula uma célula de CSV que
começa com `+` ou `-`.

**A revisão.** O revisor escreve um texto em `review` só onde a tradução atual falta, está errada ou
pode melhorar, deixa as outras linhas vazias, pode ordenar, filtrar e mover as colunas, põe em
`comment` qualquer pergunta para os mantenedores e devolve o arquivo salvo como XLSX ou como CSV em
UTF-8. O separador ponto e vírgula ou tabulação, como alguns programas de planilha gravam, e o "texto
Unicode" UTF-16 deles também são lidos; qualquer outra codificação é recusada em vez de adivinhada.

**A importação.** `import` acha cada linha pela seção e pela chave, e tira o idioma do cabeçalho
`current (<código>)`, de um nome de arquivo terminado em `-<código>.csv` ou `-<código>.xlsx`, ou de
`--lang`. Ela recusa a revisão cujos marcadores não são os do texto em inglês, a que muda um texto
que o glossário mantém em inglês (`untranslatable`), a que usa uma palavra que os `terms` do
glossário evitam naquele idioma, uma seção ou uma chave que o programa não tem (a chave desconhecida
é informada, nunca acrescentada), uma linha revisada duas vezes com textos diferentes e, num pacote,
um texto deixado em inglês onde o `test/core/i18n_glossary_test.dart` espera uma tradução (numa
escrita não latina; num pacote de escrita latina, além do seu `maxSameAsEnglish`). Ela mostra o que
muda, o que fica e o que é recusado, com o motivo, avisa quando o texto em inglês ou a tradução
mudaram desde a exportação, lista os comentários do revisor e não grava nada quando alguma revisão é
recusada, a não ser com `--force-partial` (o código de saída continua 1); `--dry-run` não grava
nada. O pacote é editado no lugar: um texto alterado é trocado onde está, uma chave que falta é
inserida onde a tabela de textos a tem, com a indentação das vizinhas, e todo o resto do arquivo
fica byte a byte como estava, então o diff de uma revisão mostra só as linhas revisadas. Português e
espanhol vêm compilados no app (`lib/app/i18n.dart` e suas partes, `lib/app/tutorial/tutorial.dart`,
`lib/core/model/catalog.dart`): as mudanças deles são listadas, cada uma com o arquivo, o texto
antigo e o novo e a entrada para colar, e salvas ao lado do arquivo revisado como
`<nome>.<código>-changes.txt`, para aplicar à mão. Depois de importar, rode
`flutter test test/core/i18n_packs_test.dart test/core/i18n_glossary_test.dart`; a ferramenta em si
é testada por `test/i18n_review_test.dart`.
