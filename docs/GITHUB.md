# The repository on GitHub

What the repository page should show, for the owner to apply in the settings of
[github.com/videjunior/opencadirrigation](https://github.com/videjunior/opencadirrigation) (none of it lives in the
files of the repository, except the images and the templates named below). Portuguese:
[GITHUB.pt-BR.md](GITHUB.pt-BR.md).

## About (the box at the top right)

Edit it with the gear beside **About**.

- **Description** (in English, the language of the code and of most visitors):

  > Free, open-source irrigation design software in the browser: draw or import the area, lay out sprinklers, drip
  > and pivots, route and size the pipes, and get reports, plot sheets and a bill of materials, with an optional AI
  > assistant. 20 languages, works offline, MIT licence.

- **Website**: `https://opencadirrigation.com`
- **Topics** (twenty, the most GitHub allows): `irrigation`, `irrigation-design`, `drip-irrigation`,
  `sprinkler-irrigation`, `center-pivot`, `micro-irrigation`, `landscape-irrigation`, `hydraulics`, `pipe-network`,
  `agriculture`, `agtech`, `water-management`, `cad`, `dxf`, `dwg`, `gis`, `flutter`, `dart`, `pwa`, `ai-assistant`.
- Tick **Releases**; untick **Packages** and **Deployments** (the site is not deployed from GitHub).

## Social preview

Settings → General → Social preview → upload [`docs/github/social-preview.png`](github/social-preview.png)
(1280 × 640: the logo, the heading of the site and a line of facts). It is what messaging apps and social networks
show for a link to the repository. Make it again after the heading of the site changes:

```
node tool/og/render_social.js   # Chrome's own headless screenshot; nothing to install
```

## Discussions

Settings → General → Features → tick **Discussions**. Then, in the Discussions tab, keep or create these categories;
each has a form in [`.github/DISCUSSION_TEMPLATE/`](../.github/DISCUSSION_TEMPLATE/), found by the slug of the
category (the end of its address), so keep the slugs as they are:

| Category | Slug | Format | Form |
|---|---|---|---|
| Announcements | `announcements` | Announcement (only maintainers post) | none: new versions, with the changes of CHANGELOG.md |
| Q&A | `q-a` | Question / Answer | `q-a.yml`: the question, the version, a project or a screenshot |
| Ideas | `ideas` | Open-ended discussion | `ideas.yml`: the task, how it is done today, what would help, the area |
| Show and tell | `show-and-tell` | Open-ended discussion | `show-and-tell.yml`: a project designed with the app |
| Translations | `translations` | Open-ended discussion (create it) | `translations.yml`: the language and what to change, or a reviewed file |
| Catalogues | `catalogues` | Open-ended discussion (create it) | `catalogues.yml`: manufacturer or standard, the items with their data sheet |

Remove the **General** and **Polls** categories, or keep General for anything else. Pin a welcome discussion in
Announcements that links the [user guide](https://opencadirrigation.com/manual/), the tutorial and the categories.
The issue chooser ([`.github/ISSUE_TEMPLATE/config.yml`](../.github/ISSUE_TEMPLATE/config.yml)) already sends
questions and ideas to Discussions; that link works once Discussions are on.

## Security and versions

- Settings → Code security → **Private vulnerability reporting**: on (SECURITY.md and `/.well-known/security.txt`
  point to it).
- Each release gets a tag `vX.Y.Z` and a GitHub Release with its part of CHANGELOG.md (see CONTRIBUTING.md).
