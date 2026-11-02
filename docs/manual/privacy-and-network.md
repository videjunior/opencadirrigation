# Storage, privacy and network access

- **Autosave** in the browser's database (IndexedDB; the localStorage of earlier versions is the
  fallback, and their copies move over at start-up), 3 seconds after the last edit, when the page is
  hidden and, as an emergency copy, when it closes; **recent projects** (the last 8) in File →
  Recent projects; **versions** (the last 10 saves of every project) in File → Version history;
  **recovery** on start-up, item by item, of the projects edited and not saved (a file only opened
  is not copied until it is edited). Projects above 256 KB of JSON are stored compressed; a project
  takes up to about 64 MB after compression (about 3.5 MB where only localStorage is there). When
  even that does not fit, the embedded images are left out of the automatic copy, and the app says so
  once per project (or that the project cannot be kept there: save it to a file). A full storage first
  makes room with the oldest versions of the same project, then the versions of the other projects,
  then the other projects already saved to a file, never with work not saved to a file; when nothing
  fits, the warning stays in the status bar (and on the phone) until a copy fits. The automatic copy
  is made in the background: the browser compresses it beside the app, so a large project does not
  hold the window after a design or while editing. A browser warning appears when closing the tab
  with unsaved changes. File → Browser storage… says where the copies are, how much the site uses,
  whether the browser keeps them when space runs short (*Ask to keep it*), lists them and downloads
  them all in a ZIP; these copies are not a backup: clearing the site data erases them, and Safari
  does so after 7 days without the site unless the app is installed on the home screen. A project
  open in another window of this browser is left out of its recovery, and a shared link, a gallery
  example or a second window of the same project opens as a copy with a new uid.
- **Files**: Save writes the `.oci.json` file (the same file again where the browser lets the app
  write to it, a download otherwise), Save as… chooses another and Save as copy… keeps a copy with a
  uid of its own; Open reads from disk. Nothing is sent to any server.
- **Share by link** (File → Share by link…): the whole project, compressed, travels inside the
  address after the `#`, which browsers send to no server; whoever opens the link gets a copy in a
  new tab. Images, the photos of comments, the logo of the title block and results are left out (the
  receiver designs again); a link longer than about 60 000 characters may be cut by mail and chat
  apps, a project too large for a link is sent as a file, and a link that carries a large project asks
  before it opens.
- **Offline**: once the app has run in a browser, its service worker keeps a copy of the app (about
  20 MB, once per version, plus the language pack and the PDF fonts a start uses) and the next start,
  of the installed app or of the site, works without a network. Base maps, online elevation and
  climate, catalogues loaded by URL and the AI assistant still need one. A new version downloads in
  the background; the app then offers to reload into it (unsaved work goes to the autosave), or it
  is used from the next start. The tiles and points of the online elevation and the climate series
  downloaded are kept on the device (IndexedDB in the browser, files on the desktop), up to 200 MB
  with the oldest going first, so making the terrain or the climate again needs no network; File →
  Saved downloaded data… shows them by kind and clears them.
- **Internet access**, for what you ask: online elevation (Terrain Tiles on AWS, Open-Meteo,
  OpenTopoData in the desktop builds), site climate (NASA POWER by default, Open-Meteo historical
  weather), base maps (OpenStreetMap or the street map server you set, OpenTopoMap, CARTO, Esri,
  Google Maps with your own key, or a custom XYZ or WMS URL; the satellite tiles also for Trace on the
  image), catalogues loaded by URL and the AI assistant. Elevation and climate requests carry
  the coordinates of the site, nothing of the project. The Google Maps API key is kept in the
  browser's storage, which any script of the site could read, and sent to Google only (restrict it
  to the site in the Google Cloud console); where a tile server has no imagery at the current zoom the
  app scales the nearest coarser tile instead of showing a "no data" placeholder. The fonts of
  every script and symbol (Chinese, Japanese, Arabic and Indian scripts, emoji, arrows) come from
  the site itself, never from a font service (see [Languages and site](languages-and-site.md)).
- **AI assistant** (optional, [AI assistant](ai-assistant.md)): the one feature that sends project
  data to a third party, and only on your action. Nothing goes out until you send a message; then
  the requests go only to the company of the model you chose, Anthropic (`api.anthropic.com`) or
  OpenAI (`api.openai.com`, with `store: false`), with your key for it: your message, the files you
  attached, the project data you ticked (a compact text built from the report tables and the design
  messages, with the site position rounded to about a kilometre; the *Data sent* view shows the
  exact text of the next message), the earlier messages of the conversation and, while the model
  works, the results of the tools it calls: tables, items and pictures of the drawing over the base
  map, satellite imagery included (the terms of the imagery provider, Esri or Google, apply to what
  goes out; the pictures download their tiles as the screen does, without asking). A site search by
  address sends the address to OpenStreetMap's Nominatim (`nominatim.openstreetmap.org`), on your
  approval unless changes apply automatically. Each key stays in memory while the page is open; with
  *Remember the key on this device* it is kept in the browser storage, which any script of the site
  could read (the site's visit statistics never run in a page where the app runs). The keys never
  enter the project file, the autosave, share links or exports, and each goes only to its own
  company. Voice dictation sends the sound of your voice to the browser's speech service (Chrome
  uses Google's servers, Edge Microsoft's and Safari Apple's), which returns the text; the app
  neither records nor keeps the audio, and the text reaches the AI only when you send it. A photo
  pinned with `add_photo_comment` keeps a small copy (about 480 pixels) in the project file, left
  out of share links; the model reads only its size. The AI notes are part of the project file, so
  they travel with it and with share links. Conversations are kept in this browser's storage
  (IndexedDB) by project, with their pictures and small attached files but never the keys, so a
  reload or the project opened again brings them back; the 24 most recently saved are kept (a
  project may keep several), and *Keep conversations in this browser* in the assistant's settings
  turns this off and deletes them. A conversation exported to a file leaves the key and the photos
  you attached out. The notice when the app is in the background blinks the title of the tab and, if
  you allow them, shows system notifications; nothing of it leaves the page. What each company does
  with the requests is governed by your agreement with it.
- **Visit statistics**: the pages of opencadirrigation.com ask once whether visits may be counted
  and load Google Analytics 4 only after *Accept* (Consent Mode v2: everything denied by default,
  only the statistics granted), never in a page where the app runs, so it cannot reach projects or
  keys; *Decline*, also later with *Cookie settings* at the foot of the pages, deletes its cookies.
  The measurement id is set when the pages are generated (`OCI_ANALYTICS_ID`, empty for none). The
  privacy policy (`/privacy/`) and the terms of use (`/terms/`) are generated with the pages, and
  Help → About links them in the interface language.
- **Language and preferences** (chosen language, theme, interface size and contrast, the drawing
  and snap settings, default catalogue, the defaults of new projects and of the title block, where
  the tutorial stopped, the assistant's settings) are kept in the browser preferences.
