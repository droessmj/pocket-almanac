# Expected Calls

Local-only iPhone companion for scheduling multiple expected-call windows. Each window needs two user-created Shortcuts time-of-day triggers. Saving a window in the app does **not** schedule a system setting change.

## Your first window

The initial schedule is **November 4, 2026, 3:55–4:15 p.m. America/Chicago** (CST, UTC−06:00; 21:55–22:15 UTC). It starts with automation setup unconfirmed. Phone settings have not been changed by installing this app.

**Restoration policy: Silence unknown callers.** This is a declared default, not automatic readback of your previous preference. The workflow cannot restore an arbitrary previous setting such as Ask Reason for Calling. During a window the intended setting is Off/Never; after the final overlapping window, On/Silence.

## Build and install

Requires Xcode 26+ and XcodeGen. Minimum iOS 17: supports SwiftUI and App Intents without requiring the newest OS; cellular behavior must still be checked on each actual iOS build.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodegen generate
xcodebuild -project Sift.xcodeproj -scheme ExpectedCalls \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/ExpectedCalls CODE_SIGNING_ALLOWED=NO build
swift test --package-path apps/ExpectedCalls/Core --scratch-path build/ExpectedCallsCore
```

For a physical phone, use the ExpectedCalls scheme in `Sift.xcodeproj`, select your phone, and run. Signing uses `Config/Team.xcconfig`; a valid team, signing identity and provisioning profile are required. Development installs can expire; do not rely on the app after its signing expires. No App Group or caller/contact permissions are needed.

**Installed development profile expires November 10, 2026 at 14:37:51 UTC (8:37 a.m. CST).** The current team issued a seven-day profile. Rebuild/reinstall before expiry, or separately arrange durable signed distribution. Queued windows after expiry cannot be relied on. Tomorrow's requested window is before that expiry, but still requires configured and validated automations.

UI lifecycle check:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Sift.xcodeproj -scheme ExpectedCalls \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath build/ExpectedCalls -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO test
```

## One-time device proof before relying on it

1. In Shortcuts, make a temporary **Allow Expected Calls** shortcut with Apple's **Set Silence Unknown Callers** action explicitly **Off**, not Toggle.
2. Make **Restore Call Silencing** with the same action explicitly **On**.
3. Run both manually, inspecting Settings → Apps → Phone → Screen Unknown Callers (older iOS: Silence Unknown Callers). Confirm Off maps to Never and On maps to Silence on your build. If it does not, stop: use manual changes instead.
4. Test an unsaved number and, separately, a withheld/anonymous number. Off is not a guarantee that withheld calls ring. Focus, silent mode, carrier anonymous-call rejection/spam blocking and blocklists remain independent.
5. Test two near-future timed triggers while locked. Enable automatic execution and locked running. A successful manual run does not prove locked execution.

Search for **Silence** in the Shortcuts action picker, not “Call filtering”. **Call Filtering → Unknown Callers** is a different switch: it sorts missed calls and voicemail into a separate list. This workflow does not toggle it. **Screen Unknown Callers** is the relevant screening control. An Off action must not be assumed to disable **Ask Reason for Calling**; verify the actual setting. Restore policy here is Silence, not Ask Reason.

## Configure each saved window

Open a window's setup instructions. Use its exact **window ID and revision**, and the displayed boundary times in the phone's current time zone.

Current Apple iOS 27 instructions: create a shortcut, open **Edit → Automation → Time of Day**, and add the desired trigger. Under **Edit → Info → Privacy**, enable **Allow Running When Locked**. On older iOS, use **Shortcuts → Automation → + → Time of Day → Run Immediately** (or turn off Ask Before Running). UI labels vary; follow the controls on your phone.

For the **opening** shortcut/automation:

1. Add **Evaluate Expected Calls** from Expected Calls.
2. Set boundary to **Opening**, Window ID to the window's UUID, Revision to the displayed integer.
3. Add **If** its returned text **is `allow`**, run **Set Silence Unknown Callers → Off**.
4. End If. Do nothing for other results.
5. Add its time-of-day trigger at the displayed start time, automatic execution enabled.

For the independent **closing** shortcut/automation:

1. Add **Evaluate Expected Calls**, boundary **Closing**, same ID/revision.
2. Add **If** its returned text **is `restoreSilence`**, run **Set Silence Unknown Callers → On**.
3. End If. Do nothing for other results.
4. Trigger at the displayed end time, automatic execution enabled.

Then confirm setup in the app **only after both triggers are configured**. The ID/revision plus absolute-date evaluator guards mean recurring triggers do not open on subsequent days. A retained unclosed session may request a late restoration on a later closing run: this is deliberate recovery, not arbitrary setting control.

Do not run an opening intent merely to inspect its output during a live window: evaluation records restoration responsibility before the subsequent Apple setting action. It is not a preview or verification that Phone changed.

## Future occurrences

Tap Add, select a date, start, and end, then save. Multiple future windows can be queued, including overlaps. For **each** new occurrence create the two boundary triggers above; Shortcuts requires user setup. Reuse old shortcut pairs only after their prior window has ended and no restoration responsibility remains: update both trigger times and both ID/revision parameters. The app does not edit these for you. Keep all pairs for simultaneously queued windows.

Entries use America/Chicago; actual instants and offsets are displayed. The schedule does not move when the phone changes time zones. Time-of-day automation triggers can follow the phone's local time, so recheck both triggers after travel. During daylight-saving changes, inspect the shown UTC offsets to distinguish repeated times; a missing local time cannot be selected as an actual instant. Overnight windows need a next-day end date.

## Changes, cancellation, and recovery

- Editing invalidates that window's setup. Update both ID/revision parameters and times, then reconfirm.
- Editing or cancelling after an opening decision retains the **original closing safety path**. Keep the original close shortcut/trigger until restoration is handled. Configure replacement triggers separately.
- Cancellation before opening makes its old opening trigger a no-op.
- Cancellation during an open session is not an immediate setting change. Run Restore Call Silencing now, or set Phone to Silence manually; the retained original close may also restore Silence later.
- Overlapping configured windows delay restoration until no configured active window or ongoing owned session remains. Every queued window still needs its closing trigger.
- If a close is missed, immediately run Restore Call Silencing or set Phone to Silence manually. There is no guaranteed recovery scheduler.
- A manual screening change during a window cannot be detected. A configured closing action may overwrite it with Silence.
- After reboot, run/unlock the phone once. Inaccessible/corrupt state causes noChange, not an optimistic opening; restore manually if necessary.

## Verification and constraints

See [device validation](docs/DEVICE_VALIDATION.md) for observed results and unrun release gates, and [architecture](docs/ARCHITECTURE.md) for storage and restoration semantics. There is no account, server, analytics, contact access, call-history collection, direct Phone setter, notification-based execution, polling loop or background timing claim. Notifications are omitted; they are not a reliable setting scheduler.

## Official references checked November 3, 2026

- [Apple's Set Silence Unknown Callers action](https://support.apple.com/en-au/101583)
- [Current Phone screening controls](https://support.apple.com/en-us/111106)
- [Creating and automatically running automations, current iOS guide](https://support.apple.com/guide/shortcuts/add-automations-apdfbdbd7123/ios)
- [App Intents result values](https://developer.apple.com/documentation/appintents/intentresult/result(value:))
