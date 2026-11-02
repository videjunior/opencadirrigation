#!/bin/sh
# Compiles the design Web Worker (lib/worker/design_worker.dart) to
# web/design_worker.js, which flutter build/run copies next to the app.
# Run it after changing lib/core, the job protocol or lib/app/i18n.dart, before
# building the web app; test/guards/worker_bundle_test.dart and CI fail when
# the committed bundle is not the one this tree compiles to.
# -O3 leaves out the implicit type checks (covariant parameters, downcasts
# from dynamic) that took a fifth of the design time; the engine gives the
# same results as with -O2 (the examples, byte for byte).
# dart2js output depends on the exact SDK: with another Flutter than the one
# pubspec.yaml pins (environment.flutter) the bundle differs from CI's.
set -e
cd "$(dirname "$0")/.."
PINNED=$(sed -n 's/^  flutter: *"\{0,1\}\([0-9][0-9.]*\).*/\1/p' pubspec.yaml | head -n 1)
CURRENT=$(dart --version 2>&1 | sed -n 's/^Dart SDK version: \([0-9][0-9.]*\).*/\1/p')
FLUTTER=$(flutter --version --machine 2>/dev/null | sed -n 's/.*"frameworkVersion": *"\([^"]*\)".*/\1/p' | head -n 1)
if [ -n "$PINNED" ] && [ -n "$FLUTTER" ] && [ "$FLUTTER" != "$PINNED" ]; then
  echo "warning: Flutter $FLUTTER (Dart $CURRENT) is not the pinned Flutter $PINNED: web/design_worker.js will not match CI's" >&2
fi
dart compile js -O3 --no-source-maps -o web/design_worker.js lib/worker/design_worker.dart
rm -f web/design_worker.js.deps
ls -la web/design_worker.js
