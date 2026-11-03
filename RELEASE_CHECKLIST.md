# App Store release checklist

Release Day in Ink (Daymark target) and Blotter (Sift target) as separate iPhone apps under the same developer account. Start with Day in Ink in TestFlight. Blotter's message filter extension is embedded in its app, with no separate store listing.

Check a task only when its result has been verified. Local build checks do not establish paid membership, provisioning, or App Review approval.

Next input needed: confirm paid Apple Developer membership and App Store Connect access. The GitHub Pages website is prepared locally in website/dist/ using app-support@droessmj.com; publication is deferred at the user’s request. Day in Ink export/import, editable tracking types, and configurable pass/fail defaults need fresh device validation. Blotter's Activity tab and logging have been removed; build 3 is installed on the iPhone, while Day in Ink remains on build 2. The app retains deletion-only cleanup of old history; the filter has no Keychain calls or explicit shared Keychain entitlement. Selected listing names are Day in Ink: Habit Tracker and Blotter: Message Filter; exact-name availability remains pending. Both apps will be free to download in all available App Store countries and regions; those account settings remain to be applied. Distribution signing, public links, store records/assets, and TestFlight uploads remain open. The concrete store-preparation work is explained in `docs/release/RELEASE_PREPARATION.md`.

## 1. Developer account and signing

- [x] Confirm separate application targets, bundle IDs, icons, and schemes exist. Both icons are 1024 × 1024 with no alpha channel.
- [x] Confirm Xcode and XcodeGen are installed (Xcode 27.1; XcodeGen available).
- [x] Confirm a team ID is configured in `Config/Team.xcconfig` (`VGRQY536X3`).
- [x] Build and development-sign the latest Sift and Daymark, and install both on the paired physical iPhone (refreshed 2026-11-02; signing profiles expire November 9 around 14:41 Central). Distribution signing and paid membership remain separate checks.
- [ ] Confirm the configured team has active paid Apple Developer Program membership.
- [ ] Confirm Xcode can create distribution signing assets. Development signing and physical-device installation succeeded; the earlier sandboxed identity check does not indicate a current development-signing failure.
- [ ] Confirm bundle IDs are registered: `com.droessmj.daymark`, `com.droessmj.sift`, and `com.droessmj.sift.filter`.
- [x] Verify the build 3 app and filter retain App Group `group.com.droessmj.sift` for keyword preferences; the filter has no explicit shared Keychain entitlement. The app retains the old access group solely for deletion-only migration.

## 2. Privacy and support

- [x] Choose public support contact: `app-support@droessmj.com` (user supplied November 3, 2026).
- [x] Use `droessmj/pocket-almanac/issues` for ordinary website support and retain email for private questions; remove the full name and care branding from the website, use actual app icons/themes, and update the local origin for the owner’s repo rename.
- [x] Build a static GitHub Pages website with a home page and separate support/privacy pages for each app in `website/dist/`; include local validation and publication instructions in `website/README.md`.
- [x] Verify all five website pages in Chrome at 1440, 390, and 320 pixels with a simulated GitHub Pages project prefix: links, styles, contact, no horizontal overflow, FAQ interaction, and keyboard skip link passed. Log: `build/app-support-browser-checks.log` (November 3, 2026).
- [x] Complete the local public-release security review of current source, all four commits, private artifact exclusions, dependencies, and remote metadata; record findings in `docs/security/PUBLIC_RELEASE_REVIEW.md`.
- [x] Prepare a manual-only GitHub Pages workflow that uploads only `website/dist/`, pins official action SHAs, and limits permissions; do not treat it as a deployed site.
- [ ] Resolve or explicitly accept existing identity/commit-email and Expected Calls schedule disclosures before making the repository public. The repo remains private.
- [ ] Verify public GitHub issue access, support mailbox delivery, and permanent HTTPS URLs after publishing the website.
- [x] Prepare privacy/support drafts in `docs/release/PRIVACY_AND_SUPPORT.md`.
- [x] Document the concrete support/privacy, pricing, screenshot, and listing work plus required user choices in `docs/release/RELEASE_PREPARATION.md`.
- [ ] Review the draft privacy and support content in `docs/release/`.
- [ ] Publish the approved privacy policies and support content; verify every URL works publicly without login.
- [ ] Add accessible privacy-policy and support links inside both apps.
- [ ] Inspect each release archive's privacy report and bundled manifests.
- [ ] Complete App Store Connect privacy answers against the final build and all SDKs. On-device-only processing may qualify for "Data Not Collected"; do not equate local storage with off-device collection.

## 3. Blotter filtering and removal of Activity

- [x] Remove the Activity tab, record/read/retention code, obsolete log-pull script, and filter Keychain access (build 3). No new message or match history is recorded.
- [x] Add deletion-only cleanup for both old Keychain services, app/shared/private legacy log files, and the old installation marker. Preserve keyword rules, options, and setup. Report app cleanup failures and retry; the extension retries its own private-file cleanup at launch.
- [x] Update setup, privacy/support drafts, listing notes, and screenshot plan to match the no-history design.
- [x] Receive user validation of the installed Sift build on the physical iPhone (2026-10-28: "Builds validated"). Device test procedure is in `apps/Sift/README.md`; individual scenario outcomes were not itemized.
- [ ] Verify matching/nonmatching keywords, case, accents, whole-word options, Contacts, and iMessage exclusions.
- [ ] Verify the Settings setup instructions on the supported iOS version.
- [ ] Validate build 3 on the iPhone: no Activity tab; saved keywords/options remain; legacy cleanup runs after launch; matching/nonmatching messages and locked-phone filtering still work.

## 4. Build and test

- [x] Run HabitKit core/backup tests (22 tests passed on 2026-11-02, including configurable defaults, legacy backup compatibility, tracking changes in both directions, history editing, and backup round trips).
- [x] Run Blotter's filtering and legacy-cleanup tests (13 passed on 2026-11-02). Earlier logging tests are superseded by Activity removal.
- [x] Build Daymark for the simulator (2026-11-02).
- [x] Run all 10 Daymark UI tests using isolated test storage on iPhone 18 Pro / iOS 27.0 (2026-11-02: complete suite passed, including tracking changes and creating/editing Failed defaults).
- [x] Build Sift and its extension for the simulator (2026-10-28).
- [x] Run `make archive-check APP=Daymark` and `make archive-check APP=Sift` to check unsigned Release packaging. Verified iPhone-only device family, version/build values, app icons, dSYMs, manifests, and the embedded Sift extension. These archives cannot be uploaded as distribution builds.
- [x] Receive user validation of the installed Daymark build on the physical iPhone (2026-10-28: "Builds validated"). Individual scenario outcomes were not itemized.
- [ ] Validate Daymark export/import on the iPhone using a backup, a cancelled import, and a confirmed restore. Earlier device acceptance predates this feature.
- [x] Allow existing Daymark habits to switch between numeric progress and pass/fail while preserving recorded tracking types, goals, and units; verify model behavior and backup round trips (2026-11-02).
- [ ] Validate Daymark tracking changes on the iPhone, including preserved history and clearing a recorded day to use the new type.
- [x] Add per-habit Passed/Failed daily defaults, preserve existing defaults when loading older saves, and verify explicit history and backup round trips (22 model/backup tests passed on 2026-11-02).
- [ ] Validate creating/editing Failed defaults, marking a pass, clearing back to the default, and relaunch persistence on the iPhone.
- [ ] Test supported older and current iOS versions. Daymark targets iOS 17+; Sift targets iOS 26+.
- [ ] Validate signed distribution archives with an Apple-accepted release of Xcode.
- [ ] Harden Day in Ink backup imports with resource limits and supported calendar bounds; avoid per-day work for large implicit streaks. See security review finding M1. No crash or data exfiltration was reproduced in the local probe.

## 5. Store records and listing assets

- [x] Start Daymark naming discovery and document public conflicts and initial alternatives in `docs/release/NAMING_RESEARCH.md` (2026-11-02).
- [x] Record the user's selected exact App Store names: Day in Ink: Habit Tracker for Daymark and Blotter: Message Filter for Sift (2026-11-02).
- [ ] Confirm these exact selected names are accepted in App Store Connect. The earlier public-catalog checks covered Word Blotter and do not confirm the revised Blotter title; authoritative confirmation is waiting for signed-in account access. See `docs/release/SIFT_NAMING_RESEARCH.md`.
- [ ] Confirm available display names and create separate App Store Connect records using the existing app bundle IDs.
- [x] Apply Day in Ink and Blotter to app display names, in-app branding, extension display text, and support/privacy content. Existing bundle IDs, data paths, and Keychain identifiers remain stable. Built and installed version 1.0.0 / build 2 (2026-11-02).
- [ ] Verify the renamed apps open with existing data and check Blotter's selection label in iPhone Settings. Automated physical-device launch was blocked because the phone was locked.
- [x] Choose pricing and territories: both apps free to download in all App Store countries and regions where distribution is permitted (user confirmed November 3, 2026).
- [ ] Apply free pricing and All Countries or Regions availability in App Store Connect; set release timing.
- [x] Prepare listing descriptions, screenshot plans, and reviewer instructions in `docs/release/STORE_LISTINGS.md`.
- [x] Save initial Daymark screenshot candidates (Today, Trends, habit detail) from the passing UI tests in `docs/release/screenshots/Daymark/`.
- [ ] Review the draft listing descriptions and reviewer instructions in `docs/release/STORE_LISTINGS.md`.
- [ ] Capture current, accurate iPhone screenshots for each app using synthetic personal data.
- [ ] Finish category, age rating, content rights, privacy, export compliance, and other required App Store Connect fields.
- [ ] Enter public support/privacy URLs and private App Review contact details.

## 6. Signed upload and TestFlight

- [x] Set initial version/build numbers (both archives verified as version 1.0.0, build 1). Increase build numbers for subsequent uploads.
- [x] Advance the renamed development builds to version 1.0.0 / build 2; app and extension metadata verified (2026-11-02).
- [x] Generate the project with `xcodegen generate`; regenerate after future configuration changes.
- [ ] Archive Daymark in Xcode for Any iOS Device; validate and upload to App Store Connect.
- [ ] Invite Daymark testers; review crashes and feedback; fix release-blocking issues.
- [ ] Archive, validate, and upload Blotter after the no-history upgrade and device checks are complete.
- [ ] Supply Sift beta review notes with setup steps and a reproducible keyword test.
- [ ] Test the actual TestFlight builds on physical devices.

## 7. Review and launch

- [ ] Select the tested build for each listing and submit for App Review.
- [ ] Resolve any review feedback and retest changed builds.
- [ ] Release each approved app when ready; use manual release for control over launch timing.
- [ ] Check the live listing, install flow, support links, and first-launch experience.

## References

- [Apple submission workflow](https://developer.apple.com/app-store/submitting/)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [App privacy definitions](https://developer.apple.com/app-store/app-privacy-details/)
- [IdentityLookup message filtering](https://developer.apple.com/documentation/identitylookup/sms-and-mms-message-filtering)

## Verification log

- 2026-10-28: Reviewed target configuration and source. Existing uncommitted product changes are being preserved. No Apple account changes, uploads, or publications have been made.
- 2026-10-28: `make test-core` passed all 12 tests. The initial sandboxed attempt could not write Swift caches; the permitted rerun passed. Log: `build/release-core-tests.log`.
- 2026-10-28: Daymark simulator build passed after granting access to Xcode services and caches. Log: `build/release-daymark-build.log`. Only an iOS 27.0 simulator runtime is installed; older-OS validation remains pending.
- 2026-10-28: Sift and SiftFilter simulator build passed. Log: `build/release-sift-build.log`.
- 2026-10-28: Daymark UI tests passed all 4 tests, including creation, persistence, progress accumulation, and pass/fail flows. Log: `build/release-daymark-ui-tests.log`.
- 2026-10-28: The first Daymark archive revealed XcodeGen's target-level universal device family overriding the project-level iPhone setting, and generated Info.plists hard-coding version 1.0. Updated `project.yml` to set device family at target level and resolve versions from build settings; rechecking packaging.
- 2026-10-28: Final unsigned Release archives for Daymark, Sift, and the embedded SiftFilter passed metadata checks: version 1.0.0 / build 1, device family `[1]`, correct bundle IDs and minimum OS values, bundled privacy manifests, and dSYMs. The Sift extension has the expected IdentityLookup extension point. Archives: `build/archives/`; logs: `build/release-daymark-archive.log` and `build/release-sift-archive.log`. Signed distribution validation remains pending.
- 2026-10-28: Exported and visually inspected three Daymark screenshot candidates from the passing UI tests. They use isolated test data and measure 1206 × 2622 pixels. Final marketing selection and App Store-required size coverage remain pending.
- 2026-10-28: Fixed Sift logging: persist before filter completion, prune on reads/writes/app activation, remove plaintext fallback creation, purge old private fallback files at next process use, report storage failures, and retry failed reinstall wipes. Added an injectable keychain storage boundary and 14 passing regression tests covering retention/count limits, corruption, failures, legacy migration, concurrency, and clock changes. Log: `build/release-sift-logging-tests.log`. Physical-device tests are assigned to the user and remain unverified here; App Review acceptance of the shared-keychain design is also unresolved.
- 2026-10-28: Updated Sift simulator build and unsigned Release archive passed after the logging changes. Reverified app/extension bundle IDs, matching version/build values, iPhone-only device family, and privacy manifests. Logs: `build/release-sift-build.log` and `build/release-sift-archive.log`.
- 2026-10-28: Rebuilt both apps from current workspace source with development signing and installed them on Michael's iPhone 16 Pro using devicectl. Both are version 1.0.0 / build 1; Sift includes the updated logging and embedded filter. Logs/results: `build/device-sift-build.log`, `build/device-daymark-build.log`, `build/device-sift-install.json`, and `build/device-daymark-install.json`. Installation succeeded; user acceptance and filtering tests remain pending.
- 2026-10-28: User subsequently confirmed "Builds validated" for the installed Sift and Daymark builds. Recorded user-reported physical-device acceptance. This does not establish older-OS coverage, individual scenario results, TestFlight validation, distribution signing, or App Review acceptance.
- 2026-11-02: Enabled tracking changes in Daymark's habit editor. Recorded days keep their tracking type, goal, and unit; daily cards, logging controls, model updates, and backups support mixed historical types. HabitKit passed 19 core/backup tests. The simulator build succeeded; 7 UI tests passed in the full run. The eighth test initially inserted text at the wrong caret position; changed it to use the numeric quick-add control and verified editing history, clearing, pass/fail logging, and persistence in a passing targeted rerun. Logs: `build/daymark-tracking-ui-tests.log`, `build/daymark-tracking-history-retest.log`.
- 2026-11-02: Sift's 15 logging tests passed. Log: `build/device-sift-refresh-tests.log`. Signed device builds of both apps succeeded. Xcode initially reused profiles expiring November 4; moved only the three matching cached profiles into `build/provisioning-backup-2026-11-02/` and regenerated them using automatic signing. New Daymark, Sift, and SiftFilter profiles expire November 9 at approximately 14:41 America/Chicago. Build logs: `build/device-daymark-renew-build.log`, `build/device-sift-renew-build.log`.
- 2026-11-02: Began English-language Daymark naming discovery. Public App Store listings already use Daymark for habit trackers. Documented evidence, rejected alternatives, and the initial Little Kept / Morrowmarks candidates in `docs/release/NAMING_RESEARCH.md`. Name selection and App Store Connect availability checks remain open; no app records or domains were reserved.
- 2026-11-02: Successfully installed the refreshed Sift (including SiftFilter) and Daymark builds on Michael's iPhone 16 Pro using devicectl. Both retain the existing bundle IDs, version 1.0.0 / build 1, and app data containers. Installation results: `build/device-sift-refresh-install.json`, `build/device-daymark-refresh-install.json`. These builds include Sift keyword-only Activity and Daymark export/import plus editable tracking types. Fresh physical-device feature acceptance remains pending.
- 2026-11-02: Added a per-habit Daily default selector (Passed/true or Failed/false) for creating and editing pass/fail habits. Older saves/backups without the new setting retain Passed. Unrecorded days use the selected default; explicit history is preserved and clearing restores the default. Updated Today status, detail/trend explanations, backup tests, and support/listing drafts. All 22 core/backup tests and the complete 10-case simulator UI suite passed. Logs: `build/daymark-default-core-tests.log`, `build/daymark-default-ui-tests.log`. Rebuilt and installed the final Daymark device build; result: `build/device-daymark-default-install.json`, build log: `build/device-daymark-default-build.log`. Its profile still expires November 9 at 14:41 Central. Physical-device feature acceptance remains pending.
- 2026-11-02: Applied Day in Ink and Blotter branding, including Blotter's extension display name and Settings setup text, habit backup screens/filename, accessibility labels, and support/privacy drafts. Retained schemes, bundle IDs, habit data paths, shared preference suites, and Keychain identifiers. Advanced all targets to build 2 and regenerated the project. Both signed builds succeeded; verified product names, bundle IDs, version 1.0.0 / build 2, and profiles expiring November 9 around 14:41 Central. The renamed habit app's focused backup export/restore UI test passed. Successfully installed both builds on Michael's iPhone 16 Pro. The physical-device launch check for Blotter was rejected because the phone was locked, so launch and Settings-label acceptance remain pending. Build logs: `build/device-day-in-ink-build.log`, `build/device-blotter-build.log`; UI log: `build/day-in-ink-branding-ui-tests.log`; install results: `build/device-day-in-ink-install.json`, `build/device-blotter-install.json`. App Store Connect availability is still unconfirmed.
- 2026-11-03: Completed the user-requested removal of Blotter Activity and installed version 1.0.0 / build 3 on Michael's iPhone 16 Pro. Removed the tab/view, all history record/read/retention code, and the old log-pull script. The extension no longer has an explicit shared Keychain entitlement or Keychain calls; the app retains only scoped deletion of both old services. Upgrade cleanup also removes legacy app/shared/private log files and the obsolete marker while preserving keywords, matching options, and setup. The 13 filtering/deletion-migration tests passed on November 2; signed device build succeeded. Verified build 3 binaries have no Keychain add/read/update calls and no delete call in the filter. Updated privacy/support/listing drafts and added the release-preparation explanation. Logs: `build/blotter-cleanup-tests.log`, `build/device-blotter-cleanup-build.log`; install result: `build/device-blotter-cleanup-install.json`. Automated launch was blocked by the phone's locked state; open Blotter to run app cleanup and trigger the filter for its private legacy-file cleanup. No real-message validation of build 3 is claimed.
