# Git Yar

Professional desktop Git client built with Flutter.

**See every branch. Ship every change.**

## Screenshots

### Welcome
![Welcome screen](docs/screenshots/welcome.jpg)

### Pro workspace
![Pro workspace](docs/screenshots/workspace.jpg)

## Features

- **Pro workspace** (GitKraken-style)
  - Colored commit graph + right-click actions
  - Merge / Rebase / Cherry-pick / Reset / Tag
  - Pull (merge|rebase), Push / Force-with-lease
  - Conflict Resolver
  - File list per commit + Diff / Code editor (fullscreen popup)
  - **Professional Reports** (activity, contributors, hot files, Markdown export)
  - Sidebar: Local / Remote / Stash
  - Staging + Commit
- Open local repositories

## Website

GitHub Pages: **https://mortenaho.github.io/git-yar/**

## Run

```bash
export PATH="$HOME/flutter/bin:$PATH"
cd /home/mortenaho/Projects/git-yar
flutter pub get
flutter run -d linux
```

If `pub.dev` is blocked:

```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn
flutter pub get --offline
```

## Requirements

- Flutter 3.x
- Git on PATH
- On Linux: `kdialog` or `zenity` for folder picker
