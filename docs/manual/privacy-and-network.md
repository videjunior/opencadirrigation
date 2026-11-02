# Storage, privacy and network access

- **Autosave** in the browser storage, at most every 3 seconds of activity and when a tab is
  closed; **recent projects** (the last 8) in File → Recent projects; **versions** (the last 10
  saves of every project) in File → Version history; **recovery** on start-up when there are
  unsaved autosaves. Projects above 256 KB of JSON are stored compressed; the limit per project is
  about 3.5 MB after compression. When even that does not fit, the embedded images are left out of
  the automatic copy, and the app says so once per project (or that the project cannot be kept
  there: save it to a file). The automatic copy is made in the background: the browser compresses
  it beside the app, so a large project does not hold the window after a design or while editing.
  A browser warning appears when closing the tab with unsaved changes.
- **Files**: Save produces an `.oci.json` download; Open reads from disk. Nothing is sent to any
  server.
- **Share by link** (File → Share by link…): the whole project, compressed, travels inside the
  address after the `#`, which browsers send to no server; whoever opens the link gets a copy in a
  new tab. Images, the photos of comments and results are left out (the receiver designs again); a link longer than about
  60 000 characters may be cut by mail and chat apps, and a project too large for a link is sent as
  a file.
- **Offline**: once the app has run in a browser, its service worker keeps a copy of the app (about
  20 MB, once per version, plus the language pack and the PDF fonts a start uses) and the next start,
  of the installed app or of the site, works without a network. Base maps, online elevation and
  climate, catalogues loaded by URL and the AI assistant still need one. A new version downloads in
  the background; the app then offers to reload into it (unsaved work goes to the autosave), or it
  is used from the next start.
- **Internet access**, for what you ask: online elevation (Terrain Tiles on AWS, Open-Meteo,
  OpenTopoData in the desktop builds), site climate (Open-Meteo historical weather, NASA POWER),
  base maps (OpenStreetMap, OpenTopoMap, CARTO, Esri, Google Maps with your own key, or a custom XYZ
  or WMS URL), catalogues loaded by URL and the AI assistant. Elevation and climate requests carry
  the coordinates of the site, nothing of the project. The Google Maps API key is kept in the
  browser's storage, which any script of the site could read, and sent to Google only (restrict it
  to the site in the Google Cloud console); where a tile server has no imagery at the current zoom the
  app scales the nearest coarser tile instead of showing a "no data" placeholder. Interface fonts
  for scripts the app does not bundle are fetched from Google Fonts when first needed.
- **AI assistant** (optional, [AI assistant](ai-assistant.md)): the one feature that sends
  project data to a third party, and only on your action. Nothing goes out until you send a
  message; then the requests go only to the company of the model you chose, Anthropic
  (`api.anthropic.com`) or OpenAI (`api.openai.com`, with `store: false`), with your key for it:
  your message, the files you attached, the project data you ticked (a compact text built from the
  report tables and the design messages, with the site position rounded to about a kilometre; the
  *Data sent* view shows the exact text of the next message), the earlier messages of the
  conversation and, while the model works, the results of the tools it calls: tables, items and
  pictures of the drawing over the base map, satellite imagery included (the terms of the imagery
  provider, Esri or Google, apply to what goes out; the pictures download their tiles as the
  screen does, without asking). A site search by address sends the address to OpenStreetMap's
  Nominatim (`nominatim.openstreetmap.org`), on your approval unless changes apply automatically.
  Each key stays in memory while the page is open; with *Remember the key on this device* it is
  kept in the browser storage, which any script of the site could read (the site's visit statistics
  never run in a page where the app runs). The keys never enter the project file, the autosave, share links or
  exports, and each goes only to its own company. Voice dictation sends the sound of your voice to
  the browser's speech service (Chrome uses Google's servers, Edge Microsoft's and Safari Apple's),
  which returns the text; the app neither records nor keeps the audio, and the text reaches the AI
  only when you send it. A photo pinned with `add_photo_comment` keeps a small copy (about 480
  pixels) in the project file, left out of share links; the model reads only its size. The AI notes are part of the project file, so
  they travel with it and with share links. Conversations are kept in this browser's storage
  (IndexedDB) by project, with their pictures and small attached files but never the keys, so a
  reload or the project opened again brings them back; the 12 most recent are kept, and *Keep
  conversations in this browser* in the assistant's settings turns this off and deletes them. What each company does with the requests is governed by your agreement with it.
- **Visit statistics**: the pages of opencadirrigation.com ask once whether visits may be counted
  and load Google Analytics 4 only after *Accept* (Consent Mode v2: everything denied by default,
  only the statistics granted), never in a page where the app runs, so it cannot reach projects or
  keys; *Decline*, also later with *Cookie settings* at the foot of the pages, deletes its cookies.
  The measurement id is set when the pages are generated (`OCI_ANALYTICS_ID`, empty for none). The
  privacy policy (`/privacy/`) and the terms of use (`/terms/`) are generated with the pages, and
  Help → About links them in the interface language.
- **Language and preferences** (chosen language, theme, default catalogue, tutorial done, the
  assistant's settings) are kept in the browser preferences.
