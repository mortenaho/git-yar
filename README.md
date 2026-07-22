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

## Downloads

CI builds **Linux** and **Windows** on every push to `main` (and on tags `v*`).

- Artifacts: [Actions → Desktop builds](https://github.com/mortenaho/git-yar/actions/workflows/desktop-builds.yml)
- Tagged releases (`v1.0.0`, …): assets are attached automatically

### Linux (local)

```bash
./scripts/build_linux.sh
# → dist/git-yar-1.0.0-linux-x64.tar.gz
```

Unpack and run `git_yar` from the bundle folder (needs GTK / system Git).

### Windows

Built on GitHub Actions (`windows-latest`). Download the `git-yar-*-windows-x64.zip` artifact, unpack, run `git_yar.exe`. Git must be on PATH.

## Run (dev)

```bash
export PATH="$HOME/flutter/bin:$PATH"
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
