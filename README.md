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

**Money hub**
- Global deposit: every account you mark to count in it, added up as your total savings, plus net worth
- Expense and Deposit in two taps, with a keypad that also does sums (120+45×2), categories, note and date. Transfers move money between your own accounts
- Accounts: cash, bank, mobile wallet, savings, DPS, FDR, credit card, investment. Balances update from opening balance and activity; accounts with history archive instead of deleting
- Monthly budget with safe to spend today, plus per-category limits
- Dot-matrix spending chart, day by day against the daily budget, and a "where it went" breakdown
- Goals with progress, add or take out money, and how much to put aside each month to hit a date
- All activity by month with filters and search; tap any entry to edit or delete (with undo)
- Hide balances with one tap. Taka amounts use lakh and crore grouping (12,34,567)

**Focus**
- A working Pomodoro timer (15, 25, 50 or 90 minutes, rounds and breaks) in the dot-matrix design

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

Every push runs `.github/workflows/ci.yml`: analyze, tests, a web build and Android APKs, one per chip type. Each push to `main` publishes a release with `Life-OS-arm64.apk` (most phones) and `Life-OS-armv7.apk` (older phones) at [Releases](https://github.com/MisbahKhan0009/Life-OS/releases/latest).

To keep one signature across builds (so updates install over the old app and keep your data), add a repository secret `ANDROID_DEBUG_KEYSTORE` holding a base64-encoded debug keystore (alias `androiddebugkey`, passwords `android`).

## Structure

```
lib/
  data/       models and Hive stores (notes, money), Markdown, date and taka formatting
  theme/      colour tokens (core and Money), typography, ThemeData
  ui/         grain texture and gradient art, glass, buttons, sheets
  shell/      tabs and the floating glass nav bar
  features/   home, folders, editor (+ glass menu), settings, focus, money
assets/fonts/ Doto, Inter Tight, Geist Mono (SIL Open Font License)
```

## Roadmap

1. Notes core
2. Money hub (this build)
3. Focus: sessions linked to notes and tasks, stats, streaks, ambient sound
4. Tasks and Today, reminders, widgets
5. Databases and views, sync, collaboration
