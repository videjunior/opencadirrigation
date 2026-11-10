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
  before it opens. The page takes the link out of the address (and out of the browser's history of the
  tab) before the app and the visit statistics start, so not even the address they could read carries
  it; a link pasted into the address bar of the app already open opens in a tab of its own the same way.
- **Offline**: once the app has run in a browser, its service worker keeps a copy of the app (about
  20 MB, once per version, plus the language pack and the PDF fonts a start uses) and the next start,
  of the installed app or of the site, works without a network. Base maps, online elevation and
  climate, the weather forecast, catalogues loaded by URL and the AI assistant still need one. A new version downloads in
  the background; the app then offers to reload into it (unsaved work goes to the autosave), or it
  is used from the next start. The tiles and points of the online elevation and the climate series
  downloaded are kept on the device (IndexedDB in the browser, files on the desktop), up to 200 MB
  with the oldest going first, so making the terrain or the climate again needs no network; File →
  Saved downloaded data… shows them by kind (the weather forecast too) and clears them.
- **Internet access**, for what you ask: online elevation (Terrain Tiles on AWS, Open-Meteo,
  OpenTopoData in the desktop builds), site climate (NASA POWER by default, Open-Meteo historical
  weather), base maps (OpenStreetMap or the street map server you set, OpenTopoMap, CARTO, Esri,
  Google Maps with your own key, or a custom XYZ or WMS URL; the satellite tiles also for Trace on the
  image and for Crop rows from the image, from the same hosts: the aerial map on screen, else Google's
  satellite tiles with your key, else Esri World Imagery), catalogues loaded by URL and the AI
  assistant. Elevation and climate requests carry the coordinates of the site, nothing of the project.
  - *Climate risk over the years* downloads the NASA POWER daily series of the site
    (`power.larc.nasa.gov`, the host of the site climate) when you press Analyse, with the
    coordinates rounded to 0.01° (about 1 km), and keeps it on this device; nothing goes out when the
    series is already kept or when the site climate's own series is chosen.
  - *Irrigation forecast* sends, when you press Get the forecast, the coordinates of the site cut to 4
    decimals to `api.met.no` (MET Norway) or, if you choose it, to `api.open-meteo.com`; like any web
    request they also see your IP address, and MET Norway's own terms note that an IP address together
    with coordinates is personal data (they suggest a proxy for privacy; the app has no server, so it
    calls the service directly). The desktop builds name the app to MET Norway in a User-Agent with the
    address of the repository, as its terms ask. The answer is kept on this device (File → Saved
    downloaded data, Weather forecast) for as long as it is valid and is not fetched again before the
    service allows.
  - The PNG and the animated GIF of the programme player download the tiles of the base map on screen
    when they are drawn with it, like the pictures of the assistant. The Google Maps API key is kept in the
  browser's storage, which any script of the site could read, and sent to Google only (restrict it
  to the site in the Google Cloud console); where a tile server has no imagery at the current zoom the
  app scales the nearest coarser tile instead of showing a "no data" placeholder. The fonts of
  every script and symbol (Chinese, Japanese, Arabic and Indian scripts, emoji, arrows) come from
  the site itself, never from a font service (see [Languages and site](languages-and-site.md)).
- **AI assistant** (optional, [AI assistant](ai-assistant.md)): the one feature that sends project
  data to a third party, and only on your action. Nothing goes out until you send a message; then
  the requests go only to the company of the model you chose, with your key for it in that company's
  own header: Anthropic (`api.anthropic.com`), OpenAI (`api.openai.com`), Google
  (`generativelanguage.googleapis.com`), xAI (`api.x.ai`), Meta (`api.meta.ai`) or OpenRouter
  (`openrouter.ai`); every API that lets the app choose is asked to store nothing for later requests
  (`store: false`: OpenAI, Google, xAI, Meta, OpenRouter). They carry your message, the files you
  attached, the project data you ticked (a compact text built from the report tables and the design
  messages, with the site position rounded to about a kilometre; the *Data sent* view shows the
  exact text of the next message), the earlier messages of the conversation and, while the model
  works, the results of the tools it calls: tables, items and pictures of the drawing over the base
  map, satellite imagery included (the terms of the imagery provider, Esri or Google, apply to what
  goes out; the pictures download their tiles as the screen does, without asking). A site search by
  address sends the address to OpenStreetMap's Nominatim (`nominatim.openstreetmap.org`), on your
  approval unless changes apply automatically. Each key stays in memory while the page is open; with
  *Remember the key on this device* it is kept in the browser storage, which any script of the site
  could read, the visit statistics one (Google Analytics) included. The keys never
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
  you allow them, shows system notifications; nothing of it leaves the page. A **second opinion**
  sends the project data, your question and the answer to the company of the model that reviews it,
  with its own key; the conversation's own model reads the review only when you send it on. What each
  company does with the requests is governed by your agreement with it; on 2026-11-10 their terms
  said:
  - **Google** (<https://aistudio.google.com/docs/terms>): on the paid tier Google does not use prompts
    or responses to improve its products and logs them for 55 days, only to detect abuse and for
    legal disclosures; on the free tier of the Flash models Google uses the content and the responses
    to improve its products and machine learning, and human reviewers may read them (in the European
    Economic Area, Switzerland and the United Kingdom the paid-tier terms apply).
  - **xAI** (<https://docs.x.ai/developers/faq/security>): xAI does not train on API inputs or outputs
    without explicit permission, and keeps requests and responses, encrypted, for 30 days to audit
    suspected abuse, unless the team has turned on zero data retention. The app also sends the
    reasoning back encrypted, which keeps xAI from storing the thinking trace for later requests.
  - **Meta** (<https://dev.meta.ai/legal/commitments>, <https://dev.meta.ai/legal/terms-of-service>): on the
    *Standard* models the app offers, Meta does not use the content to train its models; it may process
    it to detect policy violations and for safety and security, and keeps content and usage data (tool
    calls, request metadata, logs, token counts) "as needed" to provide the service, for legal
    compliance, when a possible violation is flagged and for security review, with no fixed period.
    `store: false` means a response cannot be retrieved later; it is not a promise of zero retention.
  - **OpenRouter** (<https://openrouter.ai/docs/guides/privacy/data-collection.md>, <https://openrouter.ai/terms>):
    OpenRouter does not store prompts or responses unless you opt in (private logging, or letting it
    use them for a discount) or content is flagged as potential child sexual abuse material, and it keeps
    the metadata of each request (tokens, latency). Each company OpenRouter passes a request to has
    its own retention and training policy, and some may store or train on what they receive (free
    models above all); the privacy settings of your OpenRouter account, separate for paid and free
    models, decide which of them are used. The app names itself to OpenRouter with two headers
    (`HTTP-Referer: https://opencadirrigation.com`, `X-OpenRouter-Title: OpenCADIrrigation`), which
    OpenRouter uses to rank apps, and sends a session id made from the system prompt and the first
    message, nothing about you. *More models…* downloads OpenRouter's public list of models
    (`openrouter.ai/api/v1/models`) without the key or any header of the app, when the dialog opens,
    and keeps its last copy on this device.
- **Visit statistics**: every page of opencadirrigation.com and the app load Google Analytics 4 with
  its cookies `_ga` and `_ga_<id>` (each page viewed, and an `app_start` event when the app starts),
  so the number of visitors and users can be known; advertising is always denied and the address goes
  without the part after the `#`, where a share link carries the project. No notice asks: *Cookie
  settings*, at the foot of the pages, opens it, and its *Decline* deletes the cookies and stops
  loading the statistics in that browser. Like any script of the site, the statistics script runs in
  the page that holds the projects and the remembered keys.
  The measurement id is set when the pages are generated (`OCI_ANALYTICS_ID`, empty for none). The
  privacy policy (`/privacy/`) and the terms of use (`/terms/`) are generated with the pages, and
  Help → About links them in the interface language.
- **Language and preferences** (chosen language, theme, interface size and contrast, the drawing
  and snap settings, default catalogue, the defaults of new projects and of the title block, where
  the tutorial stopped, the assistant's settings) are kept in the browser preferences.
