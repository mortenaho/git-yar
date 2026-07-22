#!/usr/bin/env bash
set -euo pipefail
export PATH="${HOME}/flutter/bin:${PATH}"
cd "$(dirname "$0")"
flutter pub get --offline
flutter run -d linux --no-pub
