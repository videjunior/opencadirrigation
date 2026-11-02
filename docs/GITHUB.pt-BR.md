# O repositório no GitHub

O que a página do repositório deve mostrar, para o dono aplicar nas configurações de
[github.com/videjunior/opencadirrigation](https://github.com/videjunior/opencadirrigation) (nada disso fica nos
arquivos do repositório, a não ser as imagens e os modelos citados abaixo). Inglês: [GITHUB.md](GITHUB.md).

## About (o quadro no alto, à direita)

Edite pela engrenagem ao lado de **About**.

- **Description** (em inglês, a língua do código e da maioria dos visitantes):

  > Free, open-source irrigation design software in the browser: draw or import the area, lay out sprinklers, drip
  > and pivots, route and size the pipes, and get reports, plot sheets and a bill of materials, with an optional AI
  > assistant. 20 languages, works offline, MIT licence.

- **Website**: `https://opencadirrigation.com`
- **Topics** (vinte, o máximo que o GitHub aceita): `irrigation`, `irrigation-design`, `drip-irrigation`,
  `sprinkler-irrigation`, `center-pivot`, `micro-irrigation`, `landscape-irrigation`, `hydraulics`, `pipe-network`,
  `agriculture`, `agtech`, `water-management`, `cad`, `dxf`, `dwg`, `gis`, `flutter`, `dart`, `pwa`, `ai-assistant`.
- Marque **Releases**; desmarque **Packages** e **Deployments** (o site não é publicado pelo GitHub).

## Imagem social

Settings → General → Social preview → envie [`docs/github/social-preview.png`](github/social-preview.png)
(1280 × 640: o logotipo, o título do site e uma linha de fatos). É o que aplicativos de mensagem e redes sociais
mostram para um link do repositório. Gere de novo quando o título do site mudar:

```
node tool/og/render_social.js   # a captura sem janela do próprio Chrome; nada a instalar
```

## Discussions

Settings → General → Features → marque **Discussions**. Depois, na aba Discussions, mantenha ou crie estas
categorias; cada uma tem um formulário em [`.github/DISCUSSION_TEMPLATE/`](../.github/DISCUSSION_TEMPLATE/), achado
pelo slug da categoria (o fim do endereço dela), então mantenha os slugs como estão:

| Categoria | Slug | Formato | Formulário |
|---|---|---|---|
| Announcements | `announcements` | Announcement (só mantenedores publicam) | nenhum: versões novas, com as mudanças do CHANGELOG.md |
| Q&A | `q-a` | Question / Answer | `q-a.yml`: a pergunta, a versão, um projeto ou uma captura de tela |
| Ideas | `ideas` | Open-ended discussion | `ideas.yml`: a tarefa, como é feita hoje, o que ajudaria, a área |
| Show and tell | `show-and-tell` | Open-ended discussion | `show-and-tell.yml`: um projeto feito com o app |
| Translations | `translations` | Open-ended discussion (crie) | `translations.yml`: o idioma e o que mudar, ou um arquivo revisado |
| Catalogues | `catalogues` | Open-ended discussion (crie) | `catalogues.yml`: fabricante ou norma, os itens com a ficha técnica |

Remova as categorias **General** e **Polls**, ou mantenha General para o resto. Fixe em Announcements uma discussão
de boas-vindas com links para o [guia do usuário](https://opencadirrigation.com/pt/manual/), o tutorial e as
categorias. O seletor de issues ([`.github/ISSUE_TEMPLATE/config.yml`](../.github/ISSUE_TEMPLATE/config.yml)) já
manda perguntas e ideias para as Discussions; esse link funciona assim que elas forem ligadas.

## Segurança e versões

- Settings → Code security → **Private vulnerability reporting**: ligado (o SECURITY.md e o
  `/.well-known/security.txt` apontam para ele).
- Cada versão ganha uma tag `vX.Y.Z` e um Release do GitHub com a sua parte do CHANGELOG.md (veja o CONTRIBUTING.md).
