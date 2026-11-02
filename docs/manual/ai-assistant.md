# AI assistant

Design → AI assistant… (`AI`, `IA`, `ASK`), its button in the status bar, or **Ask the AI** on any
message card opens an AI agent that works on the open project in a panel docked beside the drawing
(a bottom sheet on phones), so you watch the drawing change while it works. It runs a model of
Anthropic (Claude, through the Messages API) or of OpenAI (GPT, through the Responses API), with
your own API key for that company: the browser (or the desktop app) calls the company's API
directly, with no server of this project in between, and the company bills the usage to your
account. The panel shows the tokens of every answer and of the conversation with an estimate in
US$ at the list prices below, which may change.

| Company | Tier | Model | Id | US$ per million tokens, input / output |
|---|---|---|---|---|
| Anthropic | top | Claude Fable 5.1 | `claude-fable-5-1` | 10 / 50 |
| Anthropic | top | Claude Opus 5.5 (the default) | `claude-opus-5-5` | 4 / 20 |
| Anthropic | intermediate | Claude Sonnet 5.5 | `claude-sonnet-5-5` | 2 / 10 |
| Anthropic | fast | Claude Haiku 5.5 | `claude-haiku-5-5` | 0.10 / 0.50 (5 × above 100 000 input tokens) |
| OpenAI | top | GPT-6 Astra | `gpt-6-astra` | 10 / 50 |
| OpenAI | intermediate | GPT-6.1 Sol | `gpt-6.1-sol` | 2 / 10 |
| OpenAI | intermediate, earlier releases | GPT-6 Sol, GPT-5.6 Terra | `gpt-6-sol`, `gpt-5.6-terra` | 2 / 10, 2 / 12 |
| OpenAI | fast | GPT-6 Luna | `gpt-6-luna` | 0.10 / 0.50 |

OpenAI prompts above 272 000 input tokens cost 2 × input and 1.5 × output; the settings also show
the cache prices of each model. Every model takes five depths of reasoning, from quick to maximum
(balanced by default). Claude Fable 5.1 and GPT-6 Astra may think for several minutes on one step,
and Claude Fable 5.1 is offered only to organisations with 30-day data retention (otherwise the
app says so and suggests Claude Opus 5.5). On Claude Fable 5.1, Opus 5.5 and Sonnet 5.5 a request a
safety classifier declines is answered by another model on Anthropic's side, priced at the model
that answered. Switching to the other company's model, or between OpenAI models, starts a new
conversation; between Claude models the conversation goes on.

## Starting with the AI

The app opens on an empty project with a start screen that asks where
the area to irrigate is and whether you want to design with the assistant (not when the address
already says what to open, an example, the tutorial or a shared project, nor after recovered work;
"Don't show this screen at start-up" and a switch in the assistant's settings turn it off). The place
is an address or place name searched on OpenStreetMap (you pick among the matches) or coordinates
in any usual form; the project is georeferenced there and the satellite map shows. **Design with AI**
opens the assistant beside the drawing with the place and your description, or a request to start a
new design, waiting in its box; nothing is sent before you press Send. **Start without AI** leaves you
on the empty, georeferenced project. On phones the assistant has a button in the top bar that spins while it works
and shows a dot when it waits for an approval, an answer or a plan decision (the docked panel's
button does the same).

## How it works

The agent keeps a to-do list of the task, asks you questions as cards with options when something is
missing (the task waits for the answers), presents its plan, and works through the program's own
tools: 75 tools sent with every request, 205 more operations it finds and runs (`find_operations`,
`run_operation`), any menu command (`run_command`, the dialogs run without opening) and about 150
settings (`get_setting`, `set_setting`), so it reaches the functions of 1.6.0 too (pump stations,
reservoirs, the agronomy dialogs, the power and water analyses, the technical documents and the
title block, block references, layer states, comparisons, the points wizard and stake-out points,
islands of areas, inserting a project) and the editing commands (stretch, fillet, chamfer, break,
join, explode, convert to area). It reads the same numbers as the reports, changes the project
through the same functions as the menus and dialogs (drawing, network, catalogue, system flows, the
design, its corrections, the automatic layouts, the analyses, the quote, exports), keeps the
project's **AI notes** (requirements, your answers and decisions, saved in the project file and
editable in the settings, each update one undo step), reads the design playbook of the project type
(12, written from the gallery examples) and the example projects, finds the site from an address
(OpenStreetMap Nominatim: at most one search a second and 8 per conversation), sets the georeference
and the base map, downloads the terrain and the climate through the app's own downloads, and imports
the drawings and GIS files you attach. It can also read a data sheet you attach (PDF, image or text,
up to 20 MB) and add its items to the catalogue, checked before they go in, and write the project's
technical report, which can be copied or put on the drawing as text. A long attachment is not put in
the message: the model reads the parts it needs (`read_attachment`) or has the smaller model of the
same company (Claude Haiku 5.5 or GPT-6 Luna) read up to 200 pages or 20 000 lines of it and answer
its question (`summarize_attachment`), whose tokens count in the meter and the spending cap.
[docs/AI_TOOLS.md](../../docs/AI_TOOLS.md), generated from the coverage map, lists what it reaches:
every function a user can reach (command actions, drawing tools, aliases, menu items, dialogs and
their options, panel fields, status bar, view options) is covered or marked as having no meaning for
the AI, each with its reason; a test fails when a new command, tool, menu item or dialog has no
route. The system prompt states the network rules, the design run and the permissions and indexes a
reference manual the model reads when it needs it (`read_manual`, 20 topics generated from the code:
items and their fields, design parameters, message codes, tools and operations, the engine's values,
and a worked example replayed against the real tools); the prompt and the tool definitions are
cached between requests.

## Vision

`view_snapshot` takes one picture of the drawing over a base map: by default the
satellite image whenever the project is georeferenced (Esri World Imagery, or Google with your
key), so the model draws over what is really on the ground, and otherwise the map on screen; the
model can also ask for the map on screen, a street map or none. The tiles are fetched off screen, so
your view and base map never change. The model also chooses what the drawing is coloured by in its
picture (layer colours, pressures, velocities, pipe sizes, the lowest and highest pressure of each
zone, or every zone in its own colour with its name at its valve) and what is marked on it: the
design messages at their items, numbered as in the Messages list, and its own changes of the task
(added in cyan, changed in amber, removed as a dashed red outline), so it checks its work; your
screen stays as it is. Every picture states its exact pixel-to-world mapping, and `image_to_world`
converts the positions the model reads on it, optionally snapping them onto the ends and lines of
existing items so that new pipes meet the old ones; a picture drawn before the georeference changed
is refused. `trace_region` outlines a field, lawn, pond or roof from one point inside it by image
analysis on the imagery (the region grows over similar colours and texture up to the tolerance at
which its area stops growing, before it leaks into the next field), far more exactly than corners
picked by eye, and `trace_fields` outlines every field of an area at once (roads, hedges, specks and
regions cut by the edge of the area left out). The model can zoom into a part, label the items, draw proposed shapes with
`preview_geometry` before creating anything, and read the ground with `terrain_picture` (hillshade,
colours by elevation, contours, slope, aspect), `terrain_profile` and `terrain_info`. Pictures are as
large as the model reads them pixel for pixel: up to 2000 pixels and about 3.6 megapixels on Claude
Opus 5.5, Sonnet 5.5 and Fable 5.1, otherwise 1568 pixels and about 1.15 megapixels, with the shorter
side at most 768 pixels on OpenAI's models; aerial and relief pictures go as JPEG, which keeps long
conversations within the request size, and attached photos are turned upright and scaled to at most
2000 pixels a side. On Claude Opus 5.5, Sonnet 5.5 and Fable 5.1 the status line shows the model's
short progress notes between steps. The panel has a button that attaches a picture of your view;
pictures and files can also be pasted into the message box (Ctrl+V) or dropped on the panel. A
setting (on by default) sends, after each round of changes, a picture framed on what changed, with
the changes marked. A photo you attach that carries its GPS position (as phones write it) comes with
where it was taken in the project and the nearest item, and the model can pin it to the drawing with
`add_photo_comment`: a review comment at that place keeping a small copy of the photo and what the
model read in it (a pump's nameplate, the state of a valve box), shown in its properties. Before it
exports a drawing sheet, the model looks at it with `preview_sheet`: the sheet as it will print, with
a check of overlapping, tiny or cut texts, a drawing that fills too little of its viewport or runs out
of it, empty title-block fields and the north arrow, scale bar and legend, each finding with where it
is, so it fixes them first.

## Pointing

"Mark a point" and "Mark a line" above the message box show the assistant where:
every click on the drawing adds an orange mark labelled A, B, C… (a line ends with a double click or
Enter; Esc drops it), each with an optional note ("pump", "mainline up to here"). The marks go with
your next message with their coordinates and show in the assistant's pictures, so "the pump at A, the
mainline along B" is read exactly; the assistant may also ask you to mark a place. They are not part
of the project (no undo step, not saved) and go when you clear them or open another project; on a
phone the assistant's sheet closes while you mark and comes back when you finish. The commands `MK`
and `MKL` start them too.

## Voice

A microphone button beside the message box dictates the message through the browser's
speech service, in the interface language (Chrome, Edge and Safari; there is none in Firefox nor in
the desktop app): the words being recognised show in a small bubble above the button and each
confirmed phrase goes into the box at the cursor, to be read and sent as if typed. The first use
says where the voice goes.

## Saved conversations

A reload of the page, or the project opened again later in the same browser,
brings its conversation back as it was, and the model goes on with the exact earlier history; an
answer the closing page cut short shows as stopped, with **Try again**. Rewinding a restored
conversation takes back only the conversation (the project's undo history does not survive a reload).

A project can keep several conversations: **Conversations of the project** in the panel lists them,
the most recent first, by their first message; a new conversation leaves the current one in the list,
and any of them opens again or is deleted. `/new` starts a new one keeping the current, `/clear`
deletes the current. The browser keeps the 24 most recently saved conversations of all projects. A
conversation exports to a JSON file and imports back, without the key (taken out of every text) and
without the photos you attached (a note stands in their place); an imported conversation goes on with
the program's own system prompt, so import only conversations of yours. The same project open in two
tabs of the browser keeps the conversation of the first one only, and the second says so.

## Control

What it may do is set in the settings: **read only**; **plan first** (it explores with reads only
and presents a plan; changes start once you approve it); **ask before each change** (the default: a
card with Apply, Skip and Stop, also for each request to another service, where Enter applies and
Esc skips, and **Apply the rest of this task** applies this change and the next ordinary ones of the
task without asking, large deletions, requests to other services and exports still confirmed); or
**apply changes automatically** (saving a file, setting the georeference and deleting more than 20
items are still confirmed). The card runs exactly what it showed: the input of a call is fixed when
it is planned, and so is the selection it acts on. Settings are classed by their effect: a view
switch is a read, a custom map server and the program's own settings are changes always confirmed,
with the host shown. What you change on the drawing while it works stays apart from its changes,
which are steps of their own in Edit → Undo, before and after yours. You can type while it works
(the message reaches it at its next step) and stop it at any time. Approving a plan with "apply
automatically" runs that task without asking; the mode chosen in the settings stays for the next
tasks. After an error or a stop the answer offers **Try again** (the same message, when nothing of
it reached the model) or **Continue**, and the settings when the fix is there (a key refused, a
model the key cannot use). Every answer that changed the project is one history entry with **Undo
these changes**, and every message has **Rewind to here**, which takes the project (through the undo
history) and the conversation back to before it. A task ends at its step limit (50 by default, up to
200) or at its spending cap (US$ 2 by default at list prices, with a warning at 80 % and a
**Continue** button for another cap). The cap is the app's own: the model is shown no token
countdown (a task budget made it stop early and suggest a new conversation), and its instructions
say there is ample context. Under every answer, **Costs by step** lists each request of the turn:
the tokens read from and written to the cache, those outside it, the output, the pictures and PDFs,
the effort and what made a step dearer (the cache not used, a change of model or effort, a large
request); `/cost` says the share read from the cache. Long conversations are summarised on the
company's server (Anthropic from 150 000 input tokens, after clearing old tool results from 80 000
while keeping the notes, the plan and the to-do list; OpenAI from 200 000, with older pictures
dropped from the request); a setting turns this off. Quick commands: `/new`, `/design`, `/check`,
`/review`, `/report`, `/quote`, `/export`, `/plan`, `/clear` and `/cost`. `/review` runs read-only
whatever the mode: the model looks at the zones, the messages marked at their items and the
pressures and velocities over the drawing, reads the messages and the report tables, and answers
with a checklist (OK, attention or problem, with the figures and where to fix each point), changing
nothing. Standing instructions in the settings apply to every conversation ("always PVC PN 80 on the
mainline"), and the conversation saves as Markdown. Conversations are not saved with the project, so
shared files and links never carry the chat or its pictures. What is sent, when, and how the keys
are kept: [Storage, privacy and network access](privacy-and-network.md).

The settings also have **Test the connection** to the model chosen (one minimal request along the
same path as the real ones: whether the key, the account and the model accept it, the time, the
tokens, the cost, the limits of the account and any field it refused), **Adjust the effort to each
stage** (Claude models: after a round of plain edits and reads only, the next step runs at low
effort; planning, designing, checking, pictures and errors go back to the effort chosen, and the
cached conversation stays), *Tell me when the app is in the background* (the title of the tab blinks
when the task waits for your approval, questions or a plan, or ends while you are in another tab or
window) and *Allow system notifications* for the same. The project's content (its notes, texts and
names) reaches the model as data, never as instructions, and AI notes that came with a file written
in another browser are read as information until you choose *Use as mine*.
