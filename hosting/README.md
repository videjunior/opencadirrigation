# Hosting of opencadirrigation.com

`hosting/firebase.json` is the Firebase Hosting configuration of the site, generated with the pages by
`dart run tool/gen_site.dart` from `tool/site.dart` (`renderHostingConfig`); `test/web_metadata_test.dart` fails when
it drifts. The deploy folder (`firebase.json` beside `public/`, the build of `tool/build_web.sh`) lives outside the
repository; this file says how to bring the versioned configuration into it.

## What the configuration does

- **Security headers on every file**: `X-Content-Type-Options: nosniff`, `X-Frame-Options: SAMEORIGIN`,
  `Referrer-Policy: strict-origin-when-cross-origin` (the map tile servers still see the site's origin, which
  their usage policies ask for) and a `Permissions-Policy` that lets the pages ask for the device position (GPS
  walks and stake-out) and the microphone (voice dictation of the AI assistant) on the site itself, and for nothing
  else.
- **Content Security Policy**: carried by the pages themselves (a `<meta http-equiv>` written by `gen_site` in every
  entry and legal page; see `contentSecurityPolicy` in `tool/site.dart`), so it works with any host. The pages have no
  inline script: their logic is `site.js`.
- **Cache**: a month for the images whose addresses carry their version (`?v=`) and for the icons; `no-cache`
  (revalidation, a cheap 304 when unchanged) for the pages, the manifests and every file of the app whose name does
  not change from build to build (`main.dart.js` and its parts, `design_worker.js`, `flutter_bootstrap.js`, `sw.js`,
  `offline.js`, `site.js`, `assets/**`, `canvaskit/**`), so that a browser without the service worker never mixes
  two builds.
- **Redirect**: the old English address `/en/` answers with a permanent redirect (301) to `/`; Firebase Hosting keeps
  the query (`/en/?example=garden` → `/?example=garden`).
- **Default addresses**: `opencadirrigation.web.app` and `opencadirrigation.firebaseapp.com` serve the same files, and
  Firebase cannot redirect by host. `site.js` sends a new visitor from them to `https://opencadirrigation.com`; whoever
  already has projects stored on one of them stays there, since the browser storage belongs to the address.
- **Check before deploying**: `predeploy` refuses a build that tool/build_web.sh did not finish (a placeholder
  `__OCI_…` left in `sw.js`, `offline.js` or `flutter_bootstrap.js`, or no `fonts/` folder): a plain
  `flutter build web` would deploy a worker that removes itself and fonts fetched from Google.

## Applying it

1. Build: `sh tool/build_web.sh` (or with `OCI_WEB_OUT=<deploy folder>/public`).
2. Copy `hosting/firebase.json` over the `firebase.json` of the deploy folder (it keeps `"public": "public"`).
3. Deploy: `firebase deploy --only hosting` from the deploy folder.
4. Check the headers: `curl -sI https://opencadirrigation.com/ | grep -iE 'permissions|referrer|cache-control'`
   and `curl -sI https://opencadirrigation.com/en/` (301 to `/`).

## The www address

`www.opencadirrigation.com` has no DNS record, so whoever types it gets an error. To serve it:

1. Firebase console → Hosting → *Add custom domain* → `www.opencadirrigation.com`, choosing **Redirect to an existing
   website** → `opencadirrigation.com` (a 301).
2. Create, at the DNS provider of the domain, the record the console shows for `www` (a `CNAME` or the `A`/`TXT`
   records it lists), and wait for the console to verify the domain and issue its certificate.
3. Check: `curl -sI https://www.opencadirrigation.com/` answers 301 with `location: https://opencadirrigation.com/`.

## Visit statistics

The pages load Google Analytics 4 only after the visitor accepts it (Consent Mode v2, everything denied by default,
only `analytics_storage` granted), never in a page where the app runs. The measurement id comes from
`OCI_ANALYTICS_ID` when the pages are generated (`OCI_ANALYTICS_ID=G-… dart run tool/gen_site.dart`; empty: no
statistics and no notice), the owner's id otherwise. In the Google Analytics property, keep the data retention at
14 months or less (Admin → Data collection and modification → Data retention), as the privacy policy states.
