# Day in Ink

Renamed to DayInInk. The scheme, source paths, bundle ID `com.droessmj.dayinink`, and the `Application Support/DayInInk` storage folder all use the new name, so an update replacing a previously installed build starts fresh instead of carrying over its data. App Store title: **Day in Ink: Habit Tracker**.

A native iPhone habit tracker with emoji cards, pastel progress rails, a weekly date strip, and separate Today, Trends, and Habits screens. Requires iOS 17+.

- Create multiple pass/fail or numeric progress habits. Choose a name, emoji, color, goal, unit, and quick-add amount.
- Log explicit passes and failures, accrue progress with +, or enter an exact daily total.
- Browse previous dates and correct records. Future dates and dates before a habit was created cannot be logged.
- Review each habit’s 7-, 30-, or 90-day chart, completion rate, streak, recorded days, and daily history.
- Edit, archive, restore, and permanently delete habits. Archiving preserves check-ins.
- Export a complete JSON backup and restore one from Files, including archived habits and recorded goal snapshots.

Run `xcodegen generate` from the repository root and select the **DayInInk** scheme in `Sift.xcodeproj`.

Data is stored atomically in `Application Support/DayInInk/habits.json` inside the app’s sandbox. No server, account, or third-party dependencies are needed. A missing file starts with six editable habits; an unreadable file is preserved and reported instead of replaced. Changes that cannot be saved are not applied in memory.

Open **Habits → About (ⓘ) → Export and import** to save a JSON backup using Files or import one. Export captures all habit settings, archived habits, IDs, creation dates, explicit check-ins, and progress with historical goals/units. Implicit pass days remain calculated rather than being written as fabricated records. The format is versioned and matches the on-device archive.

Import validates the complete file and shows its habit/check-in counts before asking to replace current data. It replaces all habits and history rather than merging. Export first if you want to retain your current data. Invalid or unsupported files and failed saves leave the current archive unchanged. If the saved archive cannot open, the recovery screen also offers **Import a backup**. Exported files are not encrypted by DayInInk; copies in Files or another provider must be managed separately.

New archives use version 2 with Gregorian local-day keys, so changing the iPhone calendar does not hide or duplicate history. Local timezone and daylight-saving behavior still apply. Version 1 files did not record their original calendar: on first upgrade or import, choose the calendar originally used. Conversion is saved only after that choice. Calendars whose missing era, cycle, or leap-month information makes conversion ambiguous are rejected without changing the original file; do not guess a different calendar. A future start date or clock rollback shows an explanatory history state instead of constructing an invalid date-picker range.

Import uses a bounded background reader. Limits are 16 MiB, 1,000 habits, 100,000 recorded entries, Gregorian years 1900–9999, and Unicode-scalar lengths of 256 for names, 32 for emoji, and 64 for units (including historical units). The encoded file-size limit can bind before the record-count ceiling. Saving enforces the same limits before replacement; no truncation is performed. Implicit passing streaks inspect explicit records rather than enumerating every day since creation.

Exact numeric editing preserves a round-trippable value, including small fractions, when reopening and saving totals, goals, or quick-add amounts. Help & Support and Privacy Policy links are available in About and recovery/migration screens.

Pass/fail habits use a per-habit **Daily default** of **Passed** (true) or **Failed** (false), chosen when creating or editing a habit. Existing habits retain Passed until changed. The default applies to unrecorded days from creation through today; changing it also updates unrecorded past days. Explicit passes and failures stay as logged, and clearing a check-in restores the current default. Default results are calculated without writing entries. Numeric habits remain unrecorded until logged. Numeric totals can exceed the goal; the progress ring and chart cap at 100%. Each recorded day snapshots its tracking type, goal, and unit, so later edits keep historical results intact. Switch between **Build progress** and **Pass / fail** in **Edit habit**. The new type applies to unrecorded days; recorded days retain their original controls and results until cleared. Completion rates include unrecorded days and today, starting at creation. An unfinished current day preserves yesterday’s streak; an explicit failure ends it.

The **DayInInkUITests** target tests creation, persistence after relaunch, progress accumulation, pass/fail/clear flows, configurable daily defaults, backup export/restore, and switching tracking types while preserving and editing recorded progress. It attaches Today, Trends, and habit-detail screenshots to the test results. Each test uses a UUID-named temporary store; this override is only compiled in Debug.
