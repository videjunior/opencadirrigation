# Changelog

What changed in each version of OpenCADIrrigation, newest first. The app shows its version in Help → About and in
the status bar; `pubspec.yaml` holds it, and the release checklist in [CONTRIBUTING.md](CONTRIBUTING.md#releasing)
adds the section of each new version here (a test fails when the current version has none). Portuguese:
[CHANGELOG.pt-BR.md](CHANGELOG.pt-BR.md).

## Unreleased

- **Privacy and terms**: the site has a privacy policy and terms of use in every language (written in Portuguese,
  English and Spanish so far), linked from the foot of the pages and from Help → About; About also says that a
  qualified professional checks and signs a design made with the app.
- **Visit statistics only with consent**: the pages ask once; Google Analytics is loaded only after *Accept*
  (Consent Mode v2, everything denied by default) and never in a page where the app runs, so it cannot reach projects
  or keys. *Cookie settings* at the foot of the pages changes the answer.
- **Security**: a Content Security Policy in every page (scripts from the site only, no inline script), a versioned
  hosting configuration (`hosting/firebase.json`) with `Referrer-Policy`, `Permissions-Policy`, revalidation of the
  app files and a permanent redirect from `/en/`; the key warnings say who could read a remembered key.
- **New version notice**: the installed app and a tab left open learn of a new version and offer to reload into it
  (unsaved work goes to the autosave).
- **Smaller offline copy**: the language packs, the PDF fonts and the licence list are kept only once used, so the
  copy kept for offline starts went from about 28 to about 17 MB, and a release no longer downloads every language.
- **One install in every language**: each language page has its own manifest (names, shortcuts and start address in
  that language), with a phone screenshot for the install sheet; `hreflang` also names the bare `pt` and `zh`.
- **Translations**: report totals, pump curve points and other labels that stayed in English in 17 languages are
  translated; one name per concept (the submain is *linha de derivação* in Portuguese and *portalaterales* in
  Spanish; German calls every emitter *Auslass*), kept by a tested glossary (`tool/i18n/glossary.json`).
- **Documentation**: a short README with the manual in `docs/manual/` (English and Portuguese), this changelog,
  `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, issue and pull request templates and `CITATION.cff`; the
  editorial rule is tested by hash.

## 1.5.2 (2026-10-31)

- The emitters of drip tapes and driplines look the same in every overlay: small dots on the line at the real
  position of each emitter, thinned when zoomed out; only their colour changes (their own pressure in the pressure
  overlay).

## 1.5.1 (2026-10-31)

- The end of a design no longer freezes the app: the automatic copy in the browser is compressed by the browser in
  the background, and the design assistant's messages come ready from the calculation.

## 1.5.0 (2026-10-31)

- A fluid drawing board with tens of thousands of items and hundreds of layers: the drawing is kept between frames,
  a heavy drawing follows pans and zooms as a moved picture, and snaps and grips no longer scan the whole project.

## 1.4.0 (2026-10-30)

- Designs up to 25 times faster with the very same results (an elimination plan for the network solver, indexed
  lookups, zone networks reused).

## 1.3.0 (2026-10-30)

- The AI assistant sees the drawing over the satellite image, outlines fields on the imagery, follows the points and
  lines the user marks on the map, takes dictation, keeps conversations in the browser, reviews a design with
  `/review`, previews a sheet before export and pins field photos with GPS.

## 1.2.0 (2026-10-26)

- The app opens on an empty project with a start screen: where the area is (an address or coordinates) and whether
  to design with the AI assistant; the assistant was reviewed and the site speaks about it.

## 1.1.0 (2026-10-25)

- The optional AI assistant (Claude or GPT with the user's own key) works on the project with the program's tools;
  automatic design (head layout, zoning, routing, field subdivision, pivot fit), hydraulic transients and a light
  theme.

## 1.0.1 (2026-10-19)

- The source code is published under the MIT licence; the site and the app say so and link the repository.

## 1.0.0 (2026-09-22)

- First public version: CAD drawing, hydraulic network, sizing by linear programming, reports, PDF sheets, DXF and
  DWG, the interactive tutorial, the example gallery, offline start and 20 languages.
