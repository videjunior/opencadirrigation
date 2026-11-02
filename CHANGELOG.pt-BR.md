# Histórico de versões

O que mudou em cada versão do OpenCADIrrigation, da mais nova para a mais antiga. O app mostra a sua versão em
Ajuda → Sobre e na barra de status; o `pubspec.yaml` a guarda, e o checklist de lançamento do
[CONTRIBUTING.md](CONTRIBUTING.md#releasing) acrescenta aqui a seção de cada versão nova. Inglês (canônico):
[CHANGELOG.md](CHANGELOG.md).

## Ainda não lançado

- **Privacidade e termos**: o site tem política de privacidade e termos de uso em todos os idiomas (escritos por
  enquanto em português, inglês e espanhol), com link no rodapé das páginas e em Ajuda → Sobre; o Sobre também diz
  que um profissional habilitado confere e assina o projeto feito com o app.
- **Estatísticas de visita só com consentimento**: as páginas perguntam uma vez; o Google Analytics só carrega
  depois de *Aceitar* (Consent Mode v2, tudo negado por padrão) e nunca numa página em que o app roda, de modo que
  não alcança projetos nem chaves. *Preferências de cookies*, no rodapé das páginas, muda a resposta.
- **Segurança**: uma Content Security Policy em cada página (scripts só do site, nenhum script inline), uma
  configuração de hospedagem versionada (`hosting/firebase.json`) com `Referrer-Policy`, `Permissions-Policy`,
  revalidação dos arquivos do app e redirecionamento permanente de `/en/`; os avisos das chaves dizem quem poderia
  ler uma chave lembrada.
- **Aviso de versão nova**: o app instalado e uma aba deixada aberta ficam sabendo da versão nova e oferecem
  recarregar nela (o trabalho não salvo vai para o autossalvamento).
- **Cópia offline menor**: os pacotes de idioma, as fontes do PDF e a lista de licenças só são guardados quando
  usados; a cópia para abrir sem rede passou de cerca de 28 para cerca de 17 MB, e um lançamento não baixa mais
  todos os idiomas.
- **Uma instalação em cada idioma**: cada página de idioma tem o seu manifest (nomes, atalhos e endereço de início
  naquele idioma), com uma captura de celular para a tela de instalação; o `hreflang` também cita os genéricos `pt`
  e `zh`.
- **Traduções**: totais do orçamento, pontos da curva da bomba e outros rótulos que ficavam em inglês em 17 idiomas
  foram traduzidos; um nome por conceito (*linha de derivação* em português, *portalaterales* em espanhol, *Auslass*
  para todo emissor em alemão), mantido por um glossário testado (`tool/i18n/glossary.json`).
- **Documentação**: um README curto com o manual em `docs/manual/` (inglês e português), este histórico,
  `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, modelos de issue e de pull request e `CITATION.cff`; a
  regra editorial é testada por hash.

## 1.5.2 (2026-10-31)

- Os emissores das fitas e dos tubos gotejadores aparecem iguais em qualquer sobreposição: pontos pequenos sobre a
  linha, na posição real de cada emissor, rareados com o zoom afastado; só a cor muda (a da sua própria pressão na
  sobreposição de pressão).

## 1.5.1 (2026-10-31)

- O fim do cálculo não trava mais o app: a cópia automática no navegador é comprimida pelo navegador em segundo
  plano, e as mensagens do assistente de projeto vêm prontas do cálculo.

## 1.5.0 (2026-10-31)

- Prancheta fluida com dezenas de milhares de itens e centenas de camadas: o desenho fica guardado entre quadros, um
  desenho pesado acompanha arrasto e zoom como imagem deslocada, e snaps e alças não varrem mais o projeto inteiro.

## 1.4.0 (2026-10-30)

- Cálculo do projeto até 25 vezes mais rápido, com exatamente os mesmos resultados.

## 1.3.0 (2026-10-30)

- O assistente de IA vê o desenho sobre a imagem de satélite, contorna talhões na imagem, segue os pontos e linhas
  marcados no mapa, aceita ditado, guarda as conversas no navegador, revisa o projeto com `/review`, confere a
  prancha antes de exportar e fixa fotos de campo com GPS.

## 1.2.0 (2026-10-26)

- O app abre num projeto vazio com uma tela de início: onde fica a área (endereço ou coordenadas) e se o projeto
  será feito com o assistente de IA; o assistente foi revisado e o site fala dele.

## 1.1.0 (2026-10-25)

- O assistente de IA opcional (Claude ou GPT, com a chave do próprio usuário) trabalha no projeto com as ferramentas
  do programa; projeto automático (distribuição de aspersores, zonas, traçado, divisão de talhões, ajuste de pivô),
  transientes hidráulicos e tema claro.

## 1.0.1 (2026-10-19)

- O código-fonte é publicado sob a licença MIT; o site e o app dizem isso e levam ao repositório.

## 1.0.0 (2026-09-22)

- Primeira versão pública: desenho CAD, rede hidráulica, dimensionamento por programação linear, relatórios,
  pranchas em PDF, DXF e DWG, tutorial interativo, galeria de exemplos, abertura sem rede e 20 idiomas.
