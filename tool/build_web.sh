#!/bin/sh
# Production web build: compiles the design worker, then the app with the
# git commit and build date baked into the version label (Help → About,
# welcome dialog, status bar, console), CanvasKit served by the site itself
# (no Google CDN, so the installed app also starts offline) and the offline
# service worker filled in (web/sw.js, tool/gen_sw.dart). Run from anywhere:
#   sh tool/build_web.sh [extra flutter build web arguments]
# OCI_WEB_OUT=<folder> writes the build there instead of build/web.
set -e
cd "$(dirname "$0")/.."
OUT="${OCI_WEB_OUT:-build/web}"
case "$OUT" in
  /*) ;;
  *) OUT="$PWD/$OUT" ;;
esac
sh tool/build_worker.sh
COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "")
DATE=$(date +%F)
echo "build web: commit ${COMMIT:-?} date $DATE -> $OUT"
flutter build web --release --no-web-resources-cdn --output "$OUT" \
  --dart-define=OCI_COMMIT="$COMMIT" \
  --dart-define=OCI_BUILD_DATE="$DATE" \
  "$@"
# flutter.js (also inlined in flutter_bootstrap.js) ends by pointing at a
# source map the build does not write: browsers and PageSpeed then fetch a
# file that is not there.
for f in "$OUT/flutter_bootstrap.js" "$OUT/flutter.js"; do
  perl -i -ne 'print unless m{^//# sourceMappingURL=flutter\.js\.map\s*$}' "$f"
done
# Offline start: the build name and the files of the build, with their
# SHA-256, into sw.js; the worker's address into offline.js. Last, since it
# hashes the files as they are served.
dart run tool/gen_sw.dart "$OUT" --commit "$COMMIT" --date "$DATE"
