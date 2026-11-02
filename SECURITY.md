# Security policy

OpenCADIrrigation runs entirely in the browser: there is no server of the project and no account. What deserves care
is what the browser keeps for the user (projects, AI conversations and, when the user asks, API keys for Anthropic,
OpenAI and Google Maps), the project carried inside share links (`#p=…`), the files the app reads (DXF, DWG, PDF,
shapefiles, images…), the offline service worker and the pages of opencadirrigation.com.

## Reporting a vulnerability

Please report it privately, not in a public issue:

1. On GitHub, open the repository's **Security** tab and choose **Report a vulnerability** (private vulnerability
   reporting: <https://github.com/videjunior/opencadirrigation/security/advisories/new>).
2. If that form is not available, open an issue that only asks for a private channel, without details of the
   vulnerability.

Say what an attacker could do, how to reproduce it (a file, a link or the steps) and which version you used (Help →
About shows it, with the build date and commit). You will get an answer as soon as the maintainer can, and credit in
the release notes if you wish.

## Supported versions

Only the version published at <https://opencadirrigation.com> receives fixes; the installed app updates itself from
there (it offers to reload when a new version is ready).

## What is in place

- No inline script in the site's pages and a Content Security Policy that allows scripts from the site only (and,
  after the visitor accepts the statistics, from Google's tag manager, never in a page where the app runs).
- Security headers on every file (`hosting/firebase.json`): `X-Content-Type-Options`, `X-Frame-Options`,
  `Referrer-Policy` and a `Permissions-Policy` limited to the device position and the microphone.
- API keys stay in memory unless the user chooses to remember them; they never go into project files, the autosave,
  share links or exports, and each is sent only to its own service.
- The service worker checks every file of a build against its SHA-256 before keeping it.

The same contact is published at `https://opencadirrigation.com/.well-known/security.txt`.
