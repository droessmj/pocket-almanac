# Architecture

## Ownership and execution

Expected Calls owns local schedule data and returns decisions. User-owned Shortcuts automations own actual time triggers and Apple's Set Silence Unknown Callers action. The app has no documented direct setter or settings readback. It does not install, edit or inspect personal automations. There is no server, polling, long Wait, BGTaskScheduler boundary timing, Call Directory override, or notification-based execution.

`Evaluate Expected Calls` takes a boundary, window UUID and revision, returning a text value:

- `allow`: confirmed matching revision, current instant in `[start, end)`. The following Shortcuts action should set Silence Unknown Callers Off.
- `restoreSilence`: an owned session is due to close and no other relevant active window/session requires continued allowance. Set Silence Unknown Callers On.
- `noChange`: wrong date, stale revision, unconfirmed setup, unavailable data, or no transition. Do not change Phone settings.

Opening and closing triggers are independent. They must not be implemented as an opening shortcut with a 20-minute Wait. The initial requested window is November 4, 2026, 21:55–22:15 UTC, displayed in America/Chicago.

## Schedule and lifecycle

Multiple windows can coexist. Each window has a stable UUID and revision. Saving an edit invalidates its setup confirmation and revises the token, making old opening triggers harmless. Each new/edited window requires explicitly confirmed boundary setup. Confirmation is a user report, not inspection of Shortcuts.

An `allow` decision establishes a closing session containing the originating window ID, revision and original end. Cancellation/removal and edits retain that session. Thus its old closing trigger can restore Silence even after the schedule has changed. New windows use independent triggers. Keep the original closing trigger until its restoration obligation is resolved.

Overlapping windows must not be silenced by the first ending boundary. Closing evaluation checks other confirmed active windows and unexpired owned sessions; responsibility remains with the later close. An active confirmed overlap can inherit responsibility even if its opening trigger was missed. This does not eliminate the need for its closing trigger.

A closing decision is a single consumed restoration request, not a permanent license for recurring old triggers to overwrite settings. Late closes can recover an outstanding owned session; they cannot recover data that was never available or detect a failed system setting action.

## Non-atomic boundary

Intent decision and Apple's subsequent setting action are not a transaction. Recording an opening obligation can succeed even if Off fails. Consuming a closing obligation can succeed even if On fails. Last evaluation is **not** verified Phone setting state, call admission, or evidence that a call rang. There is no fabricated acknowledgement/readback. Manual restoration remains the recovery path after any action error or missed boundary.

Default policy is explicitly **Silence unknown callers**, not restoration of an arbitrary original setting. Ask Reason for Calling is not a supported restoration target. If the user manually changes settings during a session, a configured closing action may replace their change with Silence.

## Time semantics

Persist absolute instants; evaluate injected dates deterministically with half-open intervals. UI dates use America/Chicago and expose offsets. End must exceed start. New schedules are future-only. Pickers select real instants, not strings silently parsed through a DST gap. Repeated local hours must be distinguished by the displayed numeric offset. Windows retain their instants after travel; Shortcuts wall-clock triggers must be rechecked in the device's new zone. Midnight crossings use distinct start and end dates.

## Persistence and privacy

The Foundation-only ExpectedCallsCore package contains models, pure schedule transitions and the store. A versioned local JSON envelope is read and atomically written under coordinated access for the app and its in-process App Intent. No extension or App Group is required. iOS file protection is complete-until-first-user-authentication, allowing intended access after first unlock; actual locked intent execution remains a hardware validation gate. Corrupt, inaccessible or unknown-version data is not reset silently and must never grant an opening.

No contacts, caller identities, phone numbers, call history or analytics are collected. No notification permission is required. Optional notification reminders were omitted rather than presented as executable scheduling.

## Operational limits

Development signing expiry, reboot before first unlock, app removal, unavailable protected data, missed Shortcuts execution, force-quit behavior, Focus, silent mode, blocked callers, carrier filtering and anonymous-call rejection can defeat the intended result. An unsaved visible number and a withheld caller ID require separate physical tests. This is not a fail-safe call-routing service. See DEVICE_VALIDATION.md before relying on it.
