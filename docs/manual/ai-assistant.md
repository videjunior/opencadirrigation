# AI assistant

Design → AI assistant… (`AI`, `IA`, `ASK`), its button in the status bar, or **Ask the AI** on any
message card opens an AI agent that works on the open project in a panel docked beside the drawing
(a bottom sheet on phones), so you watch the drawing change while it works. It runs a model of one
of six companies, with your own API key for that company: Anthropic (Claude, through the Messages
API), OpenAI (GPT, through the Responses API), Google (Gemini, through the Interactions API), xAI
(Grok, through its Responses API), Meta (Muse, through the Meta Model API in its Responses format)
or OpenRouter (one key for the models of many companies, through its Responses API). The browser
(or the desktop app) calls the company's API directly, with no server of this project in between,
and the company bills the usage to your account. The panel shows the tokens of every answer and of
the conversation with an estimate in US$ at the list prices below, which may change.

## Companies and models

The models offered, with their list prices per million tokens as each company published them on
2026-11-10 (`lib/core/ai/llm.dart` holds the table the app uses):

| Company | Tier | Model | Id | US$ per million tokens, input / output | To know |
|---|---|---|---|---|---|
| Anthropic | top | Claude Fable 5.2 | `claude-fable-5-2` | 8 / 40 | needs 30-day data retention; may think for minutes |
| Anthropic | top | Claude Opus 5.5 (the default) | `claude-opus-5-5` | 4 / 20 | |
| Anthropic | intermediate | Claude Sonnet 5.5 | `claude-sonnet-5-5` | 2 / 10 | |
| Anthropic | fast | Claude Haiku 5.5 | `claude-haiku-5-5` | 0.10 / 0.50 | 5 × above 100 000 input tokens |
| OpenAI | top | GPT-6 Astra | `gpt-6-astra` | 10 / 50 | may think for minutes |
| OpenAI | intermediate | GPT-6.1 Sol | `gpt-6.1-sol` | 2 / 10 | |
| OpenAI | fast | GPT-6.1 Terra | `gpt-6.1-terra` | 1 / 5 | |
| OpenAI | fast | GPT-6 Luna | `gpt-6-luna` | 0.10 / 0.50 | |
| OpenAI | intermediate, earlier releases | GPT-6 Sol, GPT-5.6 Terra | `gpt-6-sol`, `gpt-5.6-terra` | 2 / 10, 2 / 12 | |
| Google | top | Gemini 4 Argon | `gemini-4-argon` | 4 / 20 | half price until 1 December 2026; may think for minutes |
| Google | intermediate | Gemini 3.8 Flash | `gemini-3.8-flash` | 1.50 / 7.50 | half price until 1 January 2027; free tier |
| Google | fast | Gemini 3.5 Flash-Lite | `gemini-3.5-flash-lite` | 0.30 / 2.50 | free tier |
| xAI | top | Grok 4.7 | `grok-4.7` | 2 / 6 | 2 × from 200 000 prompt tokens |
| xAI | fast | Grok 4.3 | `grok-4.3` | 1.25 / 2.50 | 2 × from 200 000 prompt tokens |
| Meta | top | Muse Wonder | `muse-wonder-1.0` | 4 / 20 | may think for minutes |
| Meta | intermediate | Muse Spark 1.3 | `muse-spark-1.3` | 1.25 / 4.25 | |
| Meta | fast | Muse Ember | `muse-ember-1.0` | 0.10 / 0.50 | 3 × above 200 000 input tokens |
| OpenRouter | | Claude Fable 5.2, Opus 5.5, Sonnet 5.5 and Haiku 5.5; GPT-6 Astra, GPT-6.1 Sol and GPT-6.1 Terra; Gemini 4 Argon and Gemini 3.8 Flash; Grok 4.7; Muse Spark 1.3 | `anthropic/claude-opus-5.5`, `openai/gpt-6.1-sol`… | the makers' prices as OpenRouter lists them (Gemini 3.8 Flash 1.65 / 8.25) | a lower answer limit on the dearest ones |
| OpenRouter | | Auto Router, Free Models Router | `openrouter/auto`, `openrouter/free` | the price of the model it picks; free | routers |

The long-prompt rules apply to the whole request once its input passes the threshold: OpenAI's
models (also through OpenRouter) above 272 000 input tokens cost 2 × input and cache and 1.5 ×
output; Claude Haiku 5.5 above 100 000 costs 5 × everything; Grok from 200 000 prompt tokens costs
2 × everything; Muse Ember above 200 000 input tokens (cached ones included) costs 3 × everything.
Gemini 4 Argon and Gemini 3.8 Flash (also through OpenRouter) cost half the prices of the table
until the day shown, when the full price starts. The settings show the cache prices of each model
too, and the meter prices every request at the prices of its day.

Every model of Anthropic, OpenAI and Meta takes the five depths of reasoning, from *Quick* to
*Maximum* (*Balanced* by default); Gemini takes three (*Very thorough* and *Maximum* go as
*Thorough*), Grok four (*Maximum* goes as *Very thorough*), and a model added from OpenRouter's list
those the list names for it. Claude Fable 5.2, GPT-6 Astra, Gemini 4 Argon and Muse Wonder may think
for several minutes on one step, and get longer timeouts. Claude Fable 5.2 replaced Claude Fable 5.1
(a choice or a kept conversation of 5.1 goes on with 5.2) and is offered only to organisations with
30-day data retention (otherwise the app says so and suggests Claude Opus 5.5). On Claude Fable 5.2,
Opus 5.5 and Sonnet 5.5 a request a safety classifier declines is answered by another model on
Anthropic's side, priced at the model that answered.

The four clients for Google, xAI, Meta and OpenRouter were written from each company's
documentation of 2026-11-10 and are tested against scripted transcripts that copy the formats it
documents; they have not been tried against the live services (no key was used in their
development). The clients for Anthropic and OpenAI are tested the same way. What could be checked
without a key was, on 2026-11-10: a page reaches the six APIs from Chrome, Firefox and WebKit (the
engine of Safari), and xAI, whose service reads a request before it checks the key, took the
requests of the assistant as they are sent (with the tools, a picture and a tool result with a
picture) and refused only the made-up key.

## Choosing a company and a model

The settings of the assistant show a row with the six companies (a key icon marks those with a
saved key), then the models of the chosen one, each with its tier, its prices and what to know: an
introductory price and the day it ends, a free tier, a long-prompt rule, a model that reads no
pictures or calls no tools, a router, the host the data goes to. One key is enough: each company has
its own, typed under its chip with a link to the page where the company issues keys, kept for the
session or, with *Remember the key on this device*, in the browser; a second opinion can use the
key of another company when there is one. The model last chosen of each company is remembered, so
going back to a company brings its model back.

Switching to a model of another company, or between two models of a company other than Anthropic,
starts a new conversation: the earlier one is not sent to the new model (it stays in the list of the
project's conversations) and the panel says so. Between Anthropic's Claude models the conversation
goes on: the new model reads all of it again, without the cache and without the other model's
earlier reasoning, and the panel gives the tokens and the cost of that reading.

A model that calls no tools (some of OpenRouter's list) can only talk: no tool goes in its
requests, it is told so, and it answers from the project data attached to the message, giving the
menus and steps for what has to be done in the program; it reads nothing more of the project and
changes nothing. A model that reads no pictures gets none: the pictures you attach, those the tools
draw and the picture of the drawing after a change are left out, and both you and the model are
told.

## More models (OpenRouter)

With OpenRouter chosen, **More models…** under the list of models opens OpenRouter's whole list,
downloaded from `openrouter.ai` when the dialog opens (it is public and needs no key; the copy
downloaded last is kept on this device and shown, with its date, when there is no connection). Search
by name or maker; filter with *Free only*, *Reads pictures* and *Calls tools* (on at first, since the
assistant works through tools); sort *By price* or *By name*. Each row shows the maker, the price in
US$ per million tokens (input / output), the context window and whether the model reads pictures
and calls tools. Choosing a row adds the model to your list, chooses it at once and brings it back
when the app starts again; *Remove from your list* takes it out. Only the models OpenRouter serves
through its Responses API, with a text answer and a price, are listed.

- **Prices and tier**: the list prices OpenRouter publishes (cache prices when listed, otherwise the
  input price; the higher price of long prompts when the list gives one by prompt length; price
  windows by hour of the day are ignored). The tier shown for a model of the list is a band of its
  output price (top from US$ 15 per million tokens, intermediate from US$ 4, fast below), not a
  judgement of quality.
- **Routers**: the Auto Router picks a model for each request and OpenRouter bills that model's
  price; the meter prices the answer as the model that answered when it is one of the table, and
  otherwise uses the figure OpenRouter says it charged. The Free Models Router picks among free
  models.
- **Answer limit**: an answer may take the output tokens of the model's top provider (32 000 when
  the list gives none), at most 128 000 and half the context window. While a request runs,
  OpenRouter holds the price of the largest answer it allows against the account's balance, and a
  newer or small account whose balance does not cover that hold is refused; so the dearest fixed
  models answer at most 32 000 tokens (Claude Fable 5.2, GPT-6 Astra) or 64 000 (Claude Opus 5.5,
  Grok 4.7, Muse Spark 1.3), a hold of about US$ 1.30 a request.
- **Free models** have limits set by OpenRouter (in November 2026: 20 requests a minute and 50 a day,
  or 1000 a day after buying 10 credits; the day resets at 00:00 UTC), and some providers behind
  them may keep what they receive and train on it (see [Storage, privacy and network
  access](privacy-and-network.md)). A free model works under the spending cap like any other.

## Second opinion

**Second opinion** (the button on the last answer) or `/second` asks another model to check that
answer. The button lists the models that can give one: those of the other companies you have a key
for come first, each company's most capable first, then the other models of the conversation's own
company; `/second` takes the first of them. That model receives, in one request without tools, the
project data (the whole compact text the project context gives), your question and the answer, and
says whether it agrees, what holds, what does not and what to check, with the figures it rests on.
The request goes to that model's company with its own key. Its review is shown in the conversation
marked as a second opinion and counted in the cost; the conversation's own model does not read it
unless you press **Answer the review**, which sends it on as quoted material for the first model to
check, point by point, against the project with its tools.

## Notes on each company

**Anthropic and OpenAI.** As in earlier versions: the Claude models cache the prompt and the tools,
summarise long conversations on Anthropic's side and, with *Adjust the effort to each stage*, lower
the effort of plain steps; GPT goes with `store: false`, is summarised on OpenAI's side from 200 000
input tokens, and in the browser a key OpenAI rejects shows as a network failure (OpenAI's error
answers carry no CORS header).

**Google Gemini.** Create a key in Google AI Studio (`aistudio.google.com/apikey`). The requests go to
`generativelanguage.googleapis.com` through the Interactions API with `store: false` (Google keeps no
copy for later requests), the key in the `x-goog-api-key` header, the whole conversation in every
request, and the model's reasoning signatures sent back unchanged. Efforts *Quick*, *Balanced* and
*Thorough* go as Gemini's thinking levels low, medium and high. Pictures (the views of the drawing
and of the map, your photos) go at the highest media resolution, `ultra_high` (2240 tokens a
picture), or `high` (1120) for a model that turns it down; PDFs go whole (Google takes up to 50 MB
or 1000 pages each); a request is kept under 20 MB. Google caches repeated parts of the conversation by itself
(from 4096 tokens): a token read from that cache costs 5 % (Gemini 4 Argon) or 10 % (the Flash
models) of the input price, and writing to it is free; thinking tokens are billed as output. Gemini
4 Argon answers at most 65 536 output tokens here. A safety, recitation or other policy block ends
the answer as a refusal with its reason; a quota message says whether to wait (the free tier's
per-minute limits, with the wait Google gives) or to set up billing (a model with no free use, or a
project without billing). The two Flash models have a free tier with limits, on which Google may use
the content to improve its products; Gemini 4 Argon has none.

**xAI (Grok).** Create a key at `console.x.ai` (keys start with `xai-`); credits and spending limits
are on the console's billing page. The requests go to `api.x.ai/v1/responses` with `store: false`,
the whole conversation each time with the encrypted reasoning sent back unchanged, a cache key of
the conversation (so its requests reach the server that cached it) and the sampling xAI's guide asks
for (temperature 0.7, top-p 0.95). Grok always reasons; the effort goes as xAI's `reasoning.effort`.
Caching is automatic and writing to it is free; reasoning tokens are billed as output; a request
whose prompt reaches 200 000 tokens pays twice the prices for all its tokens. Grok reads JPEG and PNG
only, so a WebP or GIF you attach is converted first, at the same size. A PDF goes as the text read
from it on this device: attached whole, it would turn on xAI's attachment search, which xAI bills per
search. xAI's own server-side tools (web search, X search, code execution) are never turned on, and
long conversations are not summarised on xAI's side. A key xAI does not know, an account out of
credit and a spending limit are told apart.

**Meta (Muse).** Create a key at `dev.meta.ai/api-keys` (keys start with `LLM_`) and add a payment
method under Billing. Meta has no hard spending cap, only an e-mail alert, so the assistant's own
cap is the limit. The requests go to `api.meta.ai/v1/responses` with `store: false`, the whole
conversation each time with the encrypted reasoning sent back unchanged; the pictures the tools
draw go inside the tool results, your pictures and PDFs in your message (Meta takes at most 50
pictures a request, and reads the text of a PDF's first 100 pages). The three models take every
effort. Meta caches
repeated prompt beginnings by itself; cached input costs much less (Muse Wonder US$ 0.20 instead of
4 per million tokens) and writing to the cache is not billed. Only Meta's *Standard* models are
offered, on which Meta does not train; the discounted *Contributor* models, on which it trains, are
not. In a browser Meta does not let the page read the request id or the rate-limit headers, so the
connection test shows no limits there (the desktop app does).

**OpenRouter.** Create a key at `openrouter.ai/settings/keys` (keys start with `sk-or-`) and buy
credits; OpenRouter bills its credits and passes each request on to the company that runs the model.
The requests go to `openrouter.ai/api/v1/responses` with `store: false`, the reasoning of Claude, GPT
and Gemini models carried through the tool calls, Claude's prompt cache turned on, a session id
derived from the conversation so that its requests stay with one provider and find their cache
again, and two headers that name the app to OpenRouter (`HTTP-Referer: https://opencadirrigation.com`,
`X-OpenRouter-Title: OpenCADIrrigation`), nothing about you. Pictures of tool results go inside the
results for Claude and GPT models and right after them, in a message, for the other makers. A PDF goes
whole to a model that reads PDFs, and through OpenRouter's free PDF parser to one that does not.
OpenRouter's errors are read by their codes (no credit, a budget of the key or the workspace,
moderation, a guardrail, the free models' daily limit), and OpenRouter's own words follow the app's
explanation.

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
tools: 75 tools sent with every request, 216 more operations it finds and runs (`find_operations`,
`run_operation`), any menu command (`run_command`, the dialogs run without opening) and about 150
settings (`get_setting`, `set_setting`), so it reaches the functions of 1.6.0 too (pump stations,
reservoirs, the agronomy dialogs, the power and water analyses, the technical documents and the
title block, block references, layer states, comparisons, the points wizard and stake-out points,
islands of areas, inserting a project), those of 1.7.0 (the crop rows read from the image with
`detect_crop_rows` and `apply_crop_rows`, the climate risk with `climate_risk`, the irrigation
forecast with `irrigation_forecast`, the programme played on the plan with `programme_picture`,
`export_programme_animation` and `export_programme_calendar`, the scorecard with
`design_scorecard`, the curve digitiser with `fit_curve_points`, `apply_curve_points` and
`export_curve_points`) and the editing commands (stretch, fillet, chamfer, break, join, explode,
convert to area). It reads the same numbers as the reports, changes the project
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
the message: the model reads the parts it needs (`read_attachment`) or has the cheapest model of the
same company (Claude Haiku 5.5, GPT-6 Luna, Gemini 3.5 Flash-Lite, Grok 4.3 or Muse Ember; Claude
Haiku 5.5 through OpenRouter) read up to 200 pages or 20 000 lines of it and answer its question
(`summarize_attachment`), whose tokens count in the meter and the spending cap.
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
large as the model reads them pixel for pixel: up to 2576 pixels on the long side and about 3.6
megapixels on Claude Fable 5.2, Opus 5.5, Sonnet 5.5 and Haiku 5.5 (also through OpenRouter),
otherwise 1568 pixels and about 1.15 megapixels, with the shorter side at most 768 pixels on OpenAI's
models (also through OpenRouter); aerial and relief pictures go as JPEG, which keeps long
conversations within the request size, and attached photos are turned upright and scaled to at most
2000 pixels a side. On Claude Fable 5.2, Opus 5.5 and Sonnet 5.5 the status line shows the model's
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
dropped from the request); a setting turns this off. The models of Google, xAI, Meta and OpenRouter
are not summarised (older pictures of tool results are still dropped from their requests): start a
new conversation when one grows long. Quick commands: `/new`, `/design`, `/check`, `/review`,
`/second`, `/report`, `/quote`, `/export`, `/plan`, `/clear` and `/cost`. `/review` runs read-only
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
