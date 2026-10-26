#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v flutter >/dev/null 2>&1; then
  git clone https://github.com/flutter/flutter.git \
    --depth 1 --branch stable /tmp/flutter
  export PATH="/tmp/flutter/bin:$PATH"
fi

flutter --version
flutter pub get

flutter build web --release \
  --dart-define=MAPTILER_API_KEY="${MAPTILER_API_KEY:-}" \
  --dart-define=OPENROUTESERVICE_API_KEY="${OPENROUTESERVICE_API_KEY:-}"
