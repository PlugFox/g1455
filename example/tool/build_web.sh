#!/usr/bin/env bash
# Builds the site into example/build/web, ready for `firebase deploy`:
#
#   example/tool/build_web.sh
#
# 1. the app, for the web: Skwasm where the browser has WasmGC (Safari
#    included, see below), CanvasKit where it does not;
# 2. a link preview per page, drawn by the package itself (tool/brand_test.dart);
# 3. a page per address around the app, with its own meta and text, plus the
#    sitemap, robots.txt and the manifest (tool/site.dart);
# 4. the service worker and bootstrap (package `sw`, configured in sw.yaml).
#
# SW_VERSION (default: the short commit) names the build for the worker.
set -euo pipefail

cd "$(dirname "$0")/.."
version="${SW_VERSION:-$(git rev-parse --short=8 HEAD 2>/dev/null || echo local)}"

# The package's version, as the site shows it: from the package's pubspec,
# not the app's.
dart run pubspec_generator:generate --input ../pubspec.yaml \
  --output lib/src/catalog/g1455.pubspec.yaml.g.dart --no-timestamp

flutter build web --release --wasm --base-href / --no-source-maps \
  --dart-define=SITE_VERSION="$version"

flutter test tool/brand_test.dart --dart-define=BRAND_OUT=build/web --dart-define=BRAND_ONLY=og --reporter=compact

dart run tool/site.dart build/web "$version"

if ! dart pub global list | grep -q '^sw 0.2.0'; then
  dart pub global activate sw 0.2.0
fi
dart pub global run sw:generate --config=sw.yaml --version="$version"

# Skwasm for Safari too. Flutter's loader keeps it to Blink unless told
# otherwise (`wasmAllowList`, default {blink: true, webkit: false}), so Safari
# and every iOS browser got dart2js and CanvasKit — where each capture of the
# backdrop is a synchronous GPU readback, and the glass cost 15 to 30 ms a
# frame against Skwasm's 4 to 10. The bootstrap `sw` writes passes the loader
# one config with no way to add to it, so the key goes in here, and the build
# stops if the bootstrap no longer has the line it goes into.
anchor='config:{canvasKitBaseUrl:'
if ! grep -q "$anchor" build/web/bootstrap.js; then
  echo "build_web.sh: '$anchor' not found in bootstrap.js; cannot allow Skwasm on WebKit" >&2
  exit 1
fi
sed -i.bak "s/$anchor/config:{wasmAllowList:{webkit:true},canvasKitBaseUrl:/" build/web/bootstrap.js
rm build/web/bootstrap.js.bak

du -sh build/web
