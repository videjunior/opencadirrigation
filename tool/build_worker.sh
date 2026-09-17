#!/bin/sh
# Compiles the design Web Worker (lib/worker/design_worker.dart) to
# web/design_worker.js, which flutter build/run copies next to the app.
# Run it after changing lib/core or the job protocol, before building the web app.
set -e
cd "$(dirname "$0")/.."
dart compile js -O2 --no-source-maps -o web/design_worker.js lib/worker/design_worker.dart
rm -f web/design_worker.js.deps
ls -la web/design_worker.js
