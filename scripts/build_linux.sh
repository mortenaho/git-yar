#!/usr/bin/env bash
# Build and package Git Yar for Linux (local machine).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export PATH="${HOME}/flutter/bin:${PATH}"
# Optional mirrors if pub.dev is blocked:
# export PUB_HOSTED_URL=https://pub.flutter-io.cn
# export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

VERSION="$(grep '^version:' pubspec.yaml | sed 's/version: *//;s/+.*//')"
OUT="git-yar-${VERSION}-linux-x64"

echo "==> flutter pub get"
flutter pub get

echo "==> flutter build linux --release"
flutter build linux --release

mkdir -p dist
rm -rf "dist/${OUT}" "dist/${OUT}.tar.gz"
cp -a build/linux/x64/release/bundle "dist/${OUT}"
tar -C dist -czf "dist/${OUT}.tar.gz" "${OUT}"

echo
echo "Linux package ready:"
echo "  ${ROOT}/dist/${OUT}.tar.gz"
echo "  ${ROOT}/dist/${OUT}/git_yar   (run from that folder)"
