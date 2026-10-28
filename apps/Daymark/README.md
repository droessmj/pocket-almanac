# Daymark

A native iPhone habit tracker with emoji cards, pastel progress rails, a weekly date strip, and separate Today, Trends, and Habits screens. Requires iOS 17+.

- Create multiple pass/fail or numeric progress habits. Choose a name, emoji, color, goal, unit, and quick-add amount.
- Log explicit passes and failures, accrue progress with +, or enter an exact daily total.
- Browse previous dates and correct records. Future dates and dates before a habit was created cannot be logged.
- Review each habit’s 7-, 30-, or 90-day chart, completion rate, streak, recorded days, and daily history.
- Edit, archive, restore, and permanently delete habits. Archiving preserves check-ins.

Run `xcodegen generate` from the repository root and select the **Daymark** scheme in `Sift.xcodeproj`.

Data is stored atomically in `Application Support/Daymark/habits.json` inside the app’s sandbox. No server, account, or third-party dependencies are needed. A missing file starts with six editable habits; an unreadable file is preserved and reported instead of replaced. Changes that cannot be saved are not applied in memory.

Pass/fail habits default to passed from creation through today unless explicitly marked failed. Clearing a check-in restores that default; implicit passes are calculated without writing entries. Numeric habits remain unrecorded until logged. Numeric totals can exceed the goal; the progress ring and chart cap at 100%. Each recorded day snapshots its goal and unit, so later goal edits keep historical results intact. Tracking type cannot change after creation. Completion rates include unrecorded days and today, starting at creation. An unfinished current day preserves yesterday’s streak; an explicit failure ends it.

The **DaymarkUITests** target tests creation, persistence after relaunch, progress accumulation, and pass/fail/clear flows. It attaches Today, Trends, and habit-detail screenshots to the test results. Each test uses a UUID-named temporary store; this override is only compiled in Debug.
