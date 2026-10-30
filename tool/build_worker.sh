#!/bin/sh
# Compiles the design Web Worker (lib/worker/design_worker.dart) to
# web/design_worker.js, which flutter build/run copies next to the app.
# Run it after changing lib/core or the job protocol, before building the web app.
# -O3 leaves out the implicit type checks (covariant parameters, downcasts
# from dynamic) that took a fifth of the design time; the engine gives the
# same results as with -O2 (the examples, byte for byte).
set -e
cd "$(dirname "$0")/.."
dart compile js -O3 --no-source-maps -o web/design_worker.js lib/worker/design_worker.dart
rm -f web/design_worker.js.deps
ls -la web/design_worker.js
