#!/bin/sh
# Production web build: compiles the design worker, then the app with the
# git commit and build date baked into the version label (Help → About,
# welcome dialog, status bar, console), CanvasKit served by the site itself
# (no Google CDN, so the installed app also starts offline) and the offline
# service worker filled in (web/sw.js, tool/gen_sw.dart). Run from anywhere:
#   sh tool/build_web.sh [extra flutter build web arguments]
# OCI_WEB_OUT=<folder> writes the build there instead of build/web.
# OCI_SOURCE_MAPS=<folder> also writes the source maps, and moves them to
# <folder>/<commit>-<date>/ (never deployed: they decipher the stack traces
# users send; tool/release.dart keeps them next to the deploy folder).
#
# It refuses another Flutter than the one pubspec.yaml pins (environment.flutter):
# the worker, the formatter and CanvasKit depend on it. OCI_ALLOW_OTHER_FLUTTER=1
# builds anyway (for a local try, never for the site). A tree with uncommitted
# changes builds with the commit marked "-dirty" in the label, so that the About
# box never names a commit that is not the code it runs; tool/release.dart
# builds only clean trees.
set -e
cd "$(dirname "$0")/.."
OUT="${OCI_WEB_OUT:-build/web}"
case "$OUT" in
  /*) ;;
  *) OUT="$PWD/$OUT" ;;
esac
PINNED=$(sed -n 's/^  flutter: *"\{0,1\}\([0-9][0-9.]*\).*/\1/p' pubspec.yaml | head -n 1)
MACHINE=$(flutter --version --machine 2>/dev/null)
FLUTTER=$(printf '%s\n' "$MACHINE" | sed -n 's/.*"frameworkVersion": *"\([^"]*\)".*/\1/p' | head -n 1)
DART=$(printf '%s\n' "$MACHINE" | sed -n 's/.*"dartSdkVersion": *"\([^"]*\)".*/\1/p' | head -n 1)
if [ -z "$PINNED" ]; then
  echo "build web: pubspec.yaml has no environment.flutter pin" >&2
  exit 1
fi
if [ "$FLUTTER" != "$PINNED" ]; then
  if [ "${OCI_ALLOW_OTHER_FLUTTER:-}" = "1" ]; then
    echo "warning: building with Flutter ${FLUTTER:-?}, not the pinned $PINNED (OCI_ALLOW_OTHER_FLUTTER=1)" >&2
  else
    echo "build web: this is Flutter ${FLUTTER:-?}, the project is pinned to Flutter $PINNED (pubspec.yaml environment.flutter)" >&2
    echo "           switch Flutter, or set OCI_ALLOW_OTHER_FLUTTER=1 for a local try" >&2
    exit 1
  fi
fi
sh tool/build_worker.sh
COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "")
if [ -n "$COMMIT" ] && [ -n "$(git status --porcelain --untracked-files=no 2>/dev/null)" ]; then
  COMMIT="$COMMIT-dirty"
fi
DATE=$(date +%F)
MAPS="${OCI_SOURCE_MAPS:-}"
if [ -n "$MAPS" ]; then
  set -- --source-maps "$@"
fi
echo "build web: Flutter ${FLUTTER:-?} (Dart ${DART:-?}) commit ${COMMIT:-?} date $DATE -> $OUT"
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
# The source maps leave the build (the site never serves them), and the
# files stop pointing at them.
if [ -n "$MAPS" ]; then
  DEST="$MAPS/${COMMIT:-nocommit}-$DATE"
  mkdir -p "$DEST"
  (cd "$OUT" && find . -name '*.map' -type f) | while read -r m; do
    mkdir -p "$DEST/$(dirname "$m")"
    mv "$OUT/$m" "$DEST/$m"
  done
  find "$OUT" -name '*.js' -type f -exec perl -i -ne 'print unless m{^//# sourceMappingURL=\S+\.map\s*$}' {} +
  echo "source maps: $DEST"
fi
# version.json (written by flutter build, left to the network by the service
# worker) also names the toolchain, the commit and the date of the build.
perl -0pi -e 's/\}\s*\z/,"flutter_version":"'"$FLUTTER"'","dart_version":"'"$DART"'","commit":"'"$COMMIT"'","build_date":"'"$DATE"'"}\n/' "$OUT/version.json"
# The fallback fonts of the engine (other scripts, symbols, emoji) served by
# the site itself under fonts/, and their address in flutter_bootstrap.js: no
# start asks a font service for anything (tool/site_fonts.dart; downloaded
# once into build/web_fonts_cache).
dart run tool/site_fonts.dart "$OUT"
# Offline start: the build name and the files of the build, with their
# SHA-256, into sw.js; the worker's address into offline.js. Last, since it
# hashes the files as they are served.
dart run tool/gen_sw.dart "$OUT" --commit "$COMMIT" --date "$DATE"
