#!/bin/sh
# Production web build: compiles the design worker, then the app with the
# git commit and build date baked into the version label (Help → About,
# welcome dialog, status bar, console). Run from anywhere:
#   sh tool/build_web.sh [extra flutter build web arguments]
set -e
cd "$(dirname "$0")/.."
sh tool/build_worker.sh
COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "")
DATE=$(date +%F)
echo "build web: commit ${COMMIT:-?} date $DATE"
flutter build web --release \
  --dart-define=OCI_COMMIT="$COMMIT" \
  --dart-define=OCI_BUILD_DATE="$DATE" \
  "$@"
