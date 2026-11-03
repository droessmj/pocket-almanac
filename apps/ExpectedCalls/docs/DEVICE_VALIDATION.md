# Device validation

Date: November 3, 2026. No cellular ringing or locked boundary success is claimed without a row recording it below.

## Environment observed

- Xcode 27.2, build 27B52, installed at `/Applications/Xcode.app`.
- Shell's default xcode-select points to CommandLineTools; commands explicitly set DEVELOPER_DIR.
- Paired physical device: iPhone 16 Pro, iOS 27.0.1, build 24A446; Developer Mode enabled.
- Simulator: iPhone 18 Pro, iOS 27.0, build 24A434.
- Physical language/region, current screening mode, Focus, ringer, carrier filters and availability of a second phone: **not inspected**.
- Current development provisioning expires November 10, 2026, 14:37:51 UTC. Reinstall/re-sign before relying on later windows.

## Release gates

| Scenario | Result | Required evidence |
| --- | --- | --- |
| Apple's Off/On action mapping on target iOS | User-reported pass for Silence ↔ Off | User created both shortcuts and reported verified behavior. Ask Reason restoration is not supported or claimed. |
| Unsaved visible number before/during/after | Not run | Second-phone calls and timestamped setting/ringing observations |
| Withheld caller ID before/during/after | Not run | Separate anonymous-call test; do not infer from unsaved number |
| Locked across both boundaries | Not run | Timed actions and calls while locked |
| Ordinary termination and force quit | Not run | Record separately, including actual setting transitions |
| Reboot before boundary / first unlock | Not run | Actual Shortcuts/protected-data behavior |
| Wrong-date recurring opening | Not run on phone | No setting change on later date |
| Cancellation before opening | Not run on phone | Old trigger no-op |
| Cancellation after opening | Not run on phone | Original closing route retained and restores |
| Edit after opening | Not run on phone | Old close safety plus new setup token behavior |
| Overlapping windows | Not run on phone | First closing boundary does not silence remaining window |
| Travel / DST / midnight | Not run on phone | Actual trigger times match absolute schedule |
| Focus / carrier filtering | Not run | Record restrictions; no universal ringing claim |
| Locked App Intent persisted state | Not run | Intent reads/writes after first unlock while locked |
| Missing/corrupt/protected store | Not run on phone | noChange and manual restore guidance |

## Physical-device script

1. Record model, iOS version/build, language/region, time zone, Phone screening mode, Focus, silent mode and carrier filtering. Do not retain telephone numbers.
2. Create the manual Allow Expected Calls (Off) and Restore Call Silencing (On) shortcuts. Run both, recording timestamps and observed Phone settings. Stop automatic rollout if mappings are wrong or the action is unavailable.
3. Add a test window a few minutes ahead in Expected Calls. Configure both independent automatic boundary shortcuts with matching ID/revision, then confirm setup. Use the current iOS locked-running controls.
4. Call from an unsaved visible number before, during and after; leave the iPhone locked over both boundaries. Record setting state and ringing separately.
5. Repeat with withheld caller ID from a second phone if supported. Record unavailable rather than pass if not supported.
6. Test cancelled-before-opening, cancelled-after-opening and edited-after-opening windows; keep original closing safety triggers. Restore manually if any boundary fails.
7. Create overlapping windows. Confirm both setups. Verify first close leaves unknown-call silencing off; last close restores Silence.
8. Repeat with app terminated, force quit, reboot before boundary, and reboot before first unlock. Record separately.
9. Test next-day recurrence no-op, overnight dates, device-zone changes, and DST offset selection. Restore Silence manually after testing and remove temporary automations.

Do not claim TestFlight readiness, fail-safe restoration or anonymous-call admission until these device gates pass. The UI's schedule status and setup checkbox are not evidence of Phone setting state.

## Executed verification

- **PASS — core:** 38 deterministic tests, 0 failures. Covers boundary instants, revision invalidation, cancellation, overlaps/abutting windows, missed-opening transfer, retained original close, one-shot late close, time-zone semantics, corruption/version rejection, rollback and concurrent updates. Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path apps/ExpectedCalls/Core --scratch-path build/ExpectedCallsCore`.
- **PASS — runtime store smoke:** a temporary-store executable exercised persistent allow, overlap transfer, retained cancellation, one-shot late restoration and corruption preservation. Observed output: `ExpectedCallsCore smoke passed: persistent allow, overlap transfer, retained cancellation, one-shot late restore, and corruption preservation.` Throwaway executable and its package target were removed afterward.
- **PASS — signed device build:** ExpectedCalls scheme built against iPhoneOS 27.2 with automatic signing using the configured development team.
- **PASS — installation:** `devicectl device install app` installed `com.droessmj.expectedcalls` on the paired iPhone.
- **PASS — simulator build and UI lifecycle:** 1 end-to-end UI test passed, 0 failures on iPhone 18 Pro / iOS 27.0. Added a second window, relaunched to verify persistence, confirmed its setup, edited it, and observed setup invalidation. Result bundle: `build/ExpectedCalls/Logs/Test/Test-ExpectedCalls-2026.11.03_08-41-23--0600.xcresult`. Earlier test harness failures were fixed (composite accessibility query and offscreen control scrolling).
- **PASS — actual visual smoke:** launched the installed simulator app outside the test harness and inspected `build/ExpectedCalls/simulator-home.png`. It shows November 4, 3:55–4:15 p.m. UTC−06:00, Setup needed, restoration policy, and no fabricated evaluation.
- **PASS — physical launch and visual smoke:** initially blocked by the device lock; after user unlocked, `devicectl device process launch` succeeded. Inspected `build/ExpectedCalls/iphone-home.png`: correct November 4, 3:55–4:15 p.m. UTC−06:00 window and Setup needed.
- **USER-REPORTED PASS — manual shortcuts:** user created Allow Expected Calls / Restore Call Silencing and explicitly reported verifying the Silence unknown callers → Off approach. Accept this observation without rerunning it. Screenshot confirmed the Off action exists. This is not a locked/timed/cellular test.
- **OBSERVED — distinct settings:** screenshot `build/ExpectedCalls/phone-settings-current.png` showed Ask Reason for Calling selected, Call Filtering → Unknown Callers enabled (its description sorts missed calls/voicemail), and Verizon Spam filtering enabled (its description says spam-classified calls are silenced). The Silence action does not toggle the separate Call Filtering switch. User subsequently chose the Silence/Off workflow.
- **BLOCKED — remote UI setup:** physical XCTest runner installation failed because the free-development three-app limit is occupied by Blotter, Day in Ink and Expected Calls. No apps were removed. Apple Events and native Accessibility control were also denied; temporary inspection/control sources and executable were removed. User is being guided through direct phone setup instead.
- **NOT RUN — timed/cellular proof:** no locked intent execution, real unsaved call or anonymous-call behavior was exercised. The November 4 window remains prefilled, not armed, until the two guarded boundary automations are configured and setup is confirmed. Confirmation is a user report, not verified Phone-state readback.
