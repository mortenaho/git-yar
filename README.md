# گیت‌یار

دستیار گیت دسکتاپ با Flutter — برنچ‌ها، وضعیت فایل‌ها، تاریخچه کامیت و کارهای روزمره.

## Features

- **Pro workspace only** (GitKraken-style)
  - Colored commit graph + right-click actions
  - Merge / Rebase / Cherry-pick / Reset / Tag
  - Pull (merge|rebase), Push / Force-with-lease
  - Conflict Resolver
  - File list per commit + Diff / Code editor (fullscreen popup)
  - **Professional Reports** (activity, contributors, hot files, Markdown export)
  - Sidebar: Local / Remote / Stash
  - Staging + Commit
- Open local repositories

## اجرا

```bash
export PATH="$HOME/flutter/bin:$PATH"
cd /home/mortenaho/Projects/git-yar
flutter pub get
flutter run -d linux
```

اگر دسترسی به `pub.dev` نداشتید:

```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn
flutter pub get --offline
```

## پیش‌نیاز

- Flutter 3.x
- Git روی سیستم
- برای انتخاب پوشه در لینوکس: `kdialog` یا `zenity`
