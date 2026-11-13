# Life OS

Notes, focus and money in one calm, offline-first app. Inspired by Google Keep, Apple Notes and Notion, with a Nothing OS feel: dot-matrix numerals, warm greys, one red action colour, silky grainy gradients and Liquid Glass bars and menus.

Built with Flutter for Android, iOS, web, Windows, macOS and Linux.

## What works in this build

**Notes core**
- Home: search, filters (All, Pinned, Checklists, Images), pinned notes as a stack, recent list
- Block editor: visual Markdown. Type `#`, `##`, `###`, `-`, `1.`, `[]`, `>`, ```` ``` ```` or `---` at the start of a line and it becomes a heading, list, checklist, quote, code block or divider. Type `/` on an empty line for the block menu
- Inline images: insert from your photos, resize by dragging the corner handle, captions, full-screen zoom viewer
- Glass context menu: copy as Markdown, pin, lock, find in note, move to folder, insert image, archive, trash
- Folders with grainy gradient covers, folder pages, move notes between folders
- Archive, and Trash that keeps notes for 30 days with restore
- Light, dark and system themes
- Everything stored offline on the device (Hive)

**Shells for the next builds**
- Focus: a working Pomodoro timer (15, 25, 50 or 90 minutes, rounds and breaks) in the dot-matrix design
- Money: the Global deposit card and what is coming

The full feature plan, mood board and screen designs live in Claude artifacts (Note App Feature Plan, the mood board and Life OS App Design).

## Run it

The platform folders (`android/`, `ios/`, `web/` and so on) are not committed. Generate them once:

```bash
flutter create . --project-name life_os --org com.misbahkhan
flutter pub get
flutter run
```

`flutter create .` only adds missing files; it never overwrites `lib/`, `test/` or `pubspec.yaml`. If you later customise a platform folder, remove it from `.gitignore` and commit it.

## CI

Every push runs `.github/workflows/ci.yml`: analyze, tests, a web build and an Android APK. Download the APK from the run's **Artifacts** section (`life-os-android-apk`).

## Structure

```
lib/
  data/       models, Hive store, Markdown conversion, date formatting
  theme/      colour tokens (core and Money), typography, ThemeData
  ui/         grain texture and gradient art, glass, buttons, sheets
  shell/      tabs and the floating glass nav bar
  features/   home, folders, editor (+ glass menu), settings, focus, money
assets/fonts/ Doto, Inter Tight, Geist Mono (SIL Open Font License)
```

## Roadmap

1. Notes core (this build)
2. Money hub: Expense and Deposit, Global deposit, accounts, budgets, goals, spending chart
3. Focus: sessions linked to notes and tasks, stats, streaks, ambient sound
4. Tasks and Today, reminders, widgets
5. Databases and views, sync, collaboration
