# Life OS

Notes, focus and money in one calm, offline-first app. Inspired by Google Keep, Apple Notes and Notion, with a Nothing OS feel: editorial serif titles and numerals, warm greys, one red action colour, silky grainy gradients and Liquid Glass bars and menus.

Built with Flutter for Android, iOS, web, Windows, macOS and Linux.

## What works in this build

**Everywhere**
- The Orbit logo: app icon (adaptive and themed on Android), dark splash screen, web icons. Regenerate with `python3 tool/make_logo.py .`
- Save from any app: share a link or text, pick **Save to Life OS**, and a popup opens over the app you were in. Add a note, pick a folder or make a new one, and you are back where you were. The note shows up in Life OS straight away
- Ask Life OS: a personal assistant (Google Gemini) that searches your notes, money and focus sessions to answer, and can write notes for you. Paste your own API key in Settings > Assistant; it stays on the device
- Light taps, springy presses and smoother transitions throughout

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
- Pomodoro with presets (Classic 25/5/15, Long 50/10/20, Deep work 90/20/30) plus your own, and Flowtime: count up, then a break worth a fifth of the time you worked
- The timer runs from the clock, so it stays right in the background and survives the app closing. Start breaks and next rounds on their own or wait for a tap; long break after a set number of rounds
- Pause, +5 minutes, finish early with the time kept, skip a break, reset
- Intention and a linked note for each session ("Focus on this" from any note's menu). Quick notes go to the linked note; distractions are counted and parked thoughts go to a Later note
- Check-in after each round: intention done, focus and energy from 1 to 5, a note, and an optional summary added to the linked note
- Breaks with ideas and a guided breathing view (box or 4-7-8). Protect breaks so they can't be skipped. Strict mode marks a round broken if you leave the app
- Ambient sound mixer (rain, ocean, fireplace, brown, pink and white noise) generated on the device, a chime, vibration and optional ticking
- Fullscreen timer, and StandBy: turn the phone sideways (or tap the StandBy button) for a landscape dial with glanceable widgets and a red night mode
- The + button stays on the Focus tab and opens a quick note
- Daily goal ring, streaks, week/month/year totals, a 20-week heatmap, best hours, completion rate, focus and energy trends, time by note, history with edit, past sessions added by hand, and CSV copy

The full feature plan, mood board and screen designs live in Claude artifacts (Note App Feature Plan, the mood board and Life OS App Design).

## Run it

The generated platform folders (`android/`, `ios/`, `web/` and so on) are not committed. Generate them once, then copy Life OS's own platform files (icon, splash, share target, manifest) over them:

```bash
flutter create . --project-name life_os --org com.misbahkhan
cp -R platform/android/. android/
cp -R platform/web/. web/
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
  ui/         grain texture and gradient art, glass, buttons, sheets, the Orbit logo
  shell/      tabs and the floating glass nav bar
  features/   home, folders, editor (+ glass menu), settings, focus, money, assistant, share popup
platform/     Android and web files copied over the generated ones (icons, splash, share target)
tool/         logo generator
assets/fonts/ Instrument Serif (titles and numbers), Inter Tight (text), Geist Mono (labels), all SIL Open Font License
```

## Roadmap

1. Notes core
2. Money hub
3. Focus (this build). Next for Focus: an ongoing notification with controls and a lock screen timer
4. Tasks and Today, reminders, widgets
5. Databases and views, sync, collaboration
