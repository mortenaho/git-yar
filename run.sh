#!/usr/bin/env bash
set -euo pipefail
export PATH="${HOME}/flutter/bin:${PATH}"
cd "$(dirname "$0")"

# pub.dev is often blocked; prefer China mirror, then offline cache.
export PUB_HOSTED_URL="${PUB_HOSTED_URL:-https://pub.flutter-io.cn}"
export FLUTTER_STORAGE_BASE_URL="${FLUTTER_STORAGE_BASE_URL:-https://storage.flutter-io.cn}"

if ! flutter pub get; then
  echo "Online pub get failed; retrying --offline from cache..." >&2
  flutter pub get --offline
fi

flutter run -d linux --no-pub
