# App Store release checklist

Release Day in Ink (DayInInk target) and Blotter (Sift target) as separate iPhone apps under the same developer account. Start with Day in Ink in TestFlight. Blotter's message filter extension is embedded in its app, with no separate store listing.

Check a task only when its result has been verified. Local build checks do not establish paid membership, provisioning, or App Review approval.

Apple Developer registration was reported complete by the user on November 3, 2026. Active program enrollment, App Store Connect access, and distribution-signing setup remain to be verified; registration alone is not recorded as proof of those account capabilities.

Latest account status reported by the user: **Enrollment Pending**. Active membership and distribution/TestFlight capability are not yet confirmed.

Application release fixes and the Blotter bundle-ID cutover are implemented locally. Current source remains version 1.0.0 / build 3. Copy-ready App Store Connect fields are in `APP_STORE_CONNECT.json`; live records have not been created because the available browser requires Apple sign-in. The support site is published, while the latest source/policy updates still need deployment. Active membership, distribution signing, signed physical-device validation, final store assets, and TestFlight uploads remain open.

## Next three steps

1. Confirm active membership and sign in to App Store Connect. Register `com.droessmj.dayinink`, `com.droessmj.blotter`, and `com.droessmj.blotter.filter`; authorize the retained Blotter App Group/cleanup Keychain group, create the two records using `APP_STORE_CONNECT.json`, and supply the private review phone number.
2. Install current development-signed builds on the iPhone. Validate Day in Ink calendar migration, backup restore/cancellation, exact numeric totals and support links; verify Blotter shared-rule continuity, explicit selection of its new filter, SMS/MMS behavior, lock-state filtering, cleanup, and support/privacy access.
3. Produce signed distribution archives, validate and upload them to App Store Connect, complete beta contact/test instructions, and test the processed TestFlight builds. External testing requires TestFlight App Review.

## 1. Developer account and signing

- [x] Confirm separate application targets, bundle IDs, icons, and schemes exist. Both icons are 1024 × 1024 with no alpha channel.
- [x] Confirm Xcode and XcodeGen are installed (Xcode 27.1; XcodeGen available).
- [x] Confirm a team ID is configured in `Config/Team.xcconfig` (`VGRQY536X3`).
- [x] Build and development-sign the latest Sift and DayInInk, and install both on the paired physical iPhone (refreshed 2026-11-02; signing profiles expire November 9 around 14:41 Central). Distribution signing and paid membership remain separate checks.
- [x] Register with Apple as a developer (user reported complete November 3, 2026).
- [ ] Confirm the configured team has active paid Apple Developer Program membership.
- [ ] Wait for the reported Enrollment Pending status to clear; verify activation before distribution signing or TestFlight upload.
- [ ] Confirm Xcode can create distribution signing assets. Development signing and physical-device installation succeeded; the earlier sandboxed identity check does not indicate a current development-signing failure.
- [ ] Confirm bundle IDs are registered: `com.droessmj.dayinink`, `com.droessmj.blotter`, and `com.droessmj.blotter.filter`.
- [x] Verify the build 3 app and filter retain App Group `group.com.droessmj.sift` for keyword preferences; the filter has no explicit shared Keychain entitlement. The app retains the old access group solely for deletion-only migration.
- [x] Change the Blotter app/extension identities to `com.droessmj.blotter` and `com.droessmj.blotter.filter`, retaining the existing App Group and legacy cleanup Keychain identifiers. Verify the new IDs and embedded extension in simulator builds and unsigned Release archives. The new identity is not an update to the old Sift bundle; private containers and filter selection do not transfer.

## 2. Privacy and support

- [x] Add root `/docs/` to `.gitignore`, remove its eleven current files from the checkout, rewrite every reachable historical snapshot without the directory, and push the cleaned history with an explicit force-with-lease. All seventeen original docs blobs were pruned from the canonical local Git object database. Private recovery material is kept only in ignored `build/docs-history-removal/`.
- [ ] Complete GitHub-side retained-copy cleanup: an older raw docs URL still returns HTTP 200, and older root-Jekyll Actions artifacts may contain copies. The available connector cannot purge retained objects or delete those runs/artifacts; instructions and a Support request draft are in ignored `build/docs-history-removal/HOSTED_CLEANUP.md`.
- [x] Choose public support contact: `app-support@droessmj.com` (user supplied November 3, 2026).
- [x] Use `droessmj/pocket-almanac/issues` for ordinary website support and retain email for private questions; remove the full name and care branding from the website, use actual app icons/themes, and update the local origin for the owner’s repo rename.
- [x] Build a static GitHub Pages website with a home page and separate support/privacy pages for each app in `website/dist/`; include local validation and publication instructions in `website/README.md`.
- [x] Verify all five website pages in Chrome at 1440, 390, and 320 pixels with a simulated GitHub Pages project prefix: links, styles, contact, no horizontal overflow, FAQ interaction, and keyboard skip link passed. Log: `build/app-support-browser-checks.log` (November 3, 2026).
- [x] Complete the local public-release security review of current source, all four commits, private artifact exclusions, dependencies, and remote metadata; record findings in `docs/security/PUBLIC_RELEASE_REVIEW.md`.
- [x] Prepare a manual-only GitHub Pages workflow that uploads only `website/dist/`, pins official action SHAs, and limits permissions; do not treat it as a deployed site.
- [x] Rewrite all five commits’ author/committer emails to `droessmj+iphone@gmail.com`, verify unchanged trees/messages/names/dates and preserved dirty files, push with an explicit force-with-lease, and set the same repo-local email for future commits (November 3, 2026).
- [x] Remove Expected Calls from current source, including its app/package/tests/docs, Xcode targets/dependency/scheme, and README schedule/setup text; regenerate the project (November 3, 2026).
- [x] Verify the regenerated project has no Expected Calls target/package/scheme references and successfully build both remaining simulator schemes. Logs: `build/remove-expected-calls-day-in-ink-build.log` and `build/remove-expected-calls-blotter-build.log`.
- [x] Keep the existing full name in source, copyright/license notices, and developer attributions, as explicitly requested by the user on November 3, 2026. The source-name disclosure is accepted; website branding continues to use the handle.
- [ ] Resolve or explicitly accept historical schedule disclosures. Expected Calls is removed locally; previously published commits/copies remain. The original five branch commits were rewritten, but old commit metadata is still anonymously retrievable by hash and the newer web-created CNAME commit uses a different email. See `docs/security/SECOND_SECURITY_PRIVACY_REVIEW.md`.
- [x] Complete a second security/privacy review: five local commits plus the remote CNAME delta, 159 historical blobs, 97 initial working files, current public repo/site, anonymous old-commit access, 56 passing unit tests, and 16 isolated adversarial probes.
- [x] Verify all five selected support/privacy/home pages over normal HTTPS and nine served files against local SHA-256 hashes at `https://apps.droessmj.com/` (November 3, 2026). The latest observed website-only workflow completed successfully.
- [ ] Enable/verify Enforce HTTPS: the reviewed HTTP endpoint returned 200 rather than upgrading, and the default GitHub URL redirected to the HTTP custom-domain URL.
- [ ] Verify public GitHub issue access, support mailbox delivery, and permanent HTTPS URLs after publishing the website.
- [x] Prepare privacy/support drafts in `docs/release/PRIVACY_AND_SUPPORT.md`.
- [x] Document the concrete support/privacy, pricing, screenshot, and listing work plus required user choices in `docs/release/RELEASE_PREPARATION.md`.
- [x] Set `https://apps.droessmj.com/` as the shared Marketing URL and prepare each app's Support and Privacy Policy URLs in `APP_STORE_CONNECT.json`. Account entry and publication of the latest source/policy changes remain pending.
- [ ] Review final privacy/support copy in `website/src/` and record/listing fields in `APP_STORE_CONNECT.json` against the shipping builds.
- [x] Observe published support/privacy content at the selected custom domain and verify all five pages publicly without login. Email delivery and HTTPS enforcement remain separate checks.
- [x] Add native privacy-policy and support links to both apps and verify that they open the public policy in simulator Safari. Blotter links remain accessible during onboarding and on Keywords, including maximum accessibility text size. Physical-device validation remains separate.
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
- [x] Build DayInInk for the simulator (2026-11-02).
- [x] Run all 10 DayInInk UI tests using isolated test storage on iPhone 18 Pro / iOS 27.0 (2026-11-02: complete suite passed, including tracking changes and creating/editing Failed defaults).
- [x] Build Sift and its extension for the simulator (2026-10-28).
- [x] Run `make archive-check APP=DayInInk` and `make archive-check APP=Sift` to check unsigned Release packaging. Verified iPhone-only device family, version/build values, app icons, dSYMs, manifests, and the embedded Sift extension. These archives cannot be uploaded as distribution builds.
- [x] Receive user validation of the installed DayInInk build on the physical iPhone (2026-10-28: "Builds validated"). Individual scenario outcomes were not itemized.
- [ ] Validate DayInInk export/import on the iPhone using a backup, a cancelled import, and a confirmed restore. Earlier device acceptance predates this feature.
- [x] Allow existing DayInInk habits to switch between numeric progress and pass/fail while preserving recorded tracking types, goals, and units; verify model behavior and backup round trips (2026-11-02).
- [ ] Validate DayInInk tracking changes on the iPhone, including preserved history and clearing a recorded day to use the new type.
- [x] Add per-habit Passed/Failed daily defaults, preserve existing defaults when loading older saves, and verify explicit history and backup round trips (22 model/backup tests passed on 2026-11-02).
- [ ] Validate creating/editing Failed defaults, marking a pass, clearing back to the default, and relaunch persistence on the iPhone.
- [ ] Test supported older and current iOS versions. DayInInk targets iOS 17+; Sift targets iOS 26+.
- [ ] Validate signed distribution archives with an Apple-accepted release of Xcode.
- [x] Bound Day in Ink backup reads/decoding/saves at 16 MiB, 1,000 habits, 100,000 entries, finite supported Gregorian dates, and Unicode text limits; reject invalid restores without replacement. Calculate implicit streaks from explicit records rather than habit age. Boundary and rollback regressions passed.
- [x] Prevent invalid history-date ranges after future creation dates or clock rollback; verify the real UI shows a safe unavailable state.
- [x] Use version 2 stable Gregorian day keys across calendar-preference changes. Require an explicit original-calendar choice for version 1 files, preserve IDs/history, and reject ambiguous era/cycle/leap-month conversions without rewriting original bytes. Verify initial upgrade choice and relaunch persistence in the simulator.
- [x] Preserve round-trippable numeric totals, goals, and quick-add values rather than rounding editable text; verify a small fractional total survives reopening, unchanged Save, and relaunch.

## 5. Store records and listing assets

- [x] Start DayInInk naming discovery and document public conflicts and initial alternatives in `docs/release/NAMING_RESEARCH.md` (2026-11-02).
- [x] Record the user's selected exact App Store names: Day in Ink: Habit Tracker for DayInInk and Blotter: Message Filter for Sift (2026-11-02).
- [ ] Confirm the selected exact names and SKUs are accepted in App Store Connect. Local preparation cannot establish availability.
- [ ] Create the two live App Store Connect records with the prepared bundle IDs and fields. The available browser reached Apple sign-in; no authenticated account changes were made.
- [x] Prepare copy-ready records in `APP_STORE_CONNECT.json`: names, SKUs, language, bundle IDs, categories, descriptions, keywords, URLs, privacy-answer basis, review notes, TestFlight instructions, and free/manual-release choices. Private review telephone details, exact-name acceptance, questionnaires, screenshots, and signed builds remain account/release tasks.
- [x] Apply Day in Ink and Blotter to app display names, in-app branding, extension display text, and support/privacy content. Existing bundle IDs, data paths, and Keychain identifiers remain stable. Built and installed version 1.0.0 / build 2 (2026-11-02).
- [ ] Verify the renamed apps open with existing data and check Blotter's selection label in iPhone Settings. Automated physical-device launch was blocked because the phone was locked.
- [x] Choose pricing and territories: both apps free to download in all App Store countries and regions where distribution is permitted (user confirmed November 3, 2026).
- [ ] Apply free pricing and All Countries or Regions availability in App Store Connect; set release timing.
- [x] Prepare listing descriptions, screenshot plans, and reviewer instructions in `docs/release/STORE_LISTINGS.md`.
- [x] Save initial DayInInk screenshot candidates (Today, Trends, habit detail) from the passing UI tests in `docs/release/screenshots/DayInInk/`.
- [ ] Review the final listing descriptions and reviewer instructions in `APP_STORE_CONNECT.json`.
- [ ] Capture current, accurate iPhone screenshots for each app using synthetic personal data.
- [ ] Finish category, age rating, content rights, privacy, export compliance, and other required App Store Connect fields.
- [ ] Enter public support/privacy URLs and private App Review contact details.

## 6. Signed upload and TestFlight

- [x] Set initial version/build numbers (both archives verified as version 1.0.0, build 1). Increase build numbers for subsequent uploads.
- [x] Advance the renamed development builds to version 1.0.0 / build 2; app and extension metadata verified (2026-11-02).
- [x] Generate the project with `xcodegen generate`; regenerate after future configuration changes.
- [ ] Archive DayInInk in Xcode for Any iOS Device; validate and upload to App Store Connect.
- [ ] Invite DayInInk testers; review crashes and feedback; fix release-blocking issues.
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
- 2026-10-28: DayInInk simulator build passed after granting access to Xcode services and caches. Log: `build/release-dayinink-build.log`. Only an iOS 27.0 simulator runtime is installed; older-OS validation remains pending.
- 2026-10-28: Sift and SiftFilter simulator build passed. Log: `build/release-sift-build.log`.
- 2026-10-28: DayInInk UI tests passed all 4 tests, including creation, persistence, progress accumulation, and pass/fail flows. Log: `build/release-dayinink-ui-tests.log`.
- 2026-10-28: The first DayInInk archive revealed XcodeGen's target-level universal device family overriding the project-level iPhone setting, and generated Info.plists hard-coding version 1.0. Updated `project.yml` to set device family at target level and resolve versions from build settings; rechecking packaging.
- 2026-10-28: Final unsigned Release archives for DayInInk, Sift, and the embedded SiftFilter passed metadata checks: version 1.0.0 / build 1, device family `[1]`, correct bundle IDs and minimum OS values, bundled privacy manifests, and dSYMs. The Sift extension has the expected IdentityLookup extension point. Archives: `build/archives/`; logs: `build/release-dayinink-archive.log` and `build/release-sift-archive.log`. Signed distribution validation remains pending.
- 2026-10-28: Exported and visually inspected three DayInInk screenshot candidates from the passing UI tests. They use isolated test data and measure 1206 × 2622 pixels. Final marketing selection and App Store-required size coverage remain pending.
- 2026-10-28: Fixed Sift logging: persist before filter completion, prune on reads/writes/app activation, remove plaintext fallback creation, purge old private fallback files at next process use, report storage failures, and retry failed reinstall wipes. Added an injectable keychain storage boundary and 14 passing regression tests covering retention/count limits, corruption, failures, legacy migration, concurrency, and clock changes. Log: `build/release-sift-logging-tests.log`. Physical-device tests are assigned to the user and remain unverified here; App Review acceptance of the shared-keychain design is also unresolved.
- 2026-10-28: Updated Sift simulator build and unsigned Release archive passed after the logging changes. Reverified app/extension bundle IDs, matching version/build values, iPhone-only device family, and privacy manifests. Logs: `build/release-sift-build.log` and `build/release-sift-archive.log`.
- 2026-10-28: Rebuilt both apps from current workspace source with development signing and installed them on Michael's iPhone 16 Pro using devicectl. Both are version 1.0.0 / build 1; Sift includes the updated logging and embedded filter. Logs/results: `build/device-sift-build.log`, `build/device-dayinink-build.log`, `build/device-sift-install.json`, and `build/device-dayinink-install.json`. Installation succeeded; user acceptance and filtering tests remain pending.
- 2026-10-28: User subsequently confirmed "Builds validated" for the installed Sift and DayInInk builds. Recorded user-reported physical-device acceptance. This does not establish older-OS coverage, individual scenario results, TestFlight validation, distribution signing, or App Review acceptance.
- 2026-11-02: Enabled tracking changes in DayInInk's habit editor. Recorded days keep their tracking type, goal, and unit; daily cards, logging controls, model updates, and backups support mixed historical types. HabitKit passed 19 core/backup tests. The simulator build succeeded; 7 UI tests passed in the full run. The eighth test initially inserted text at the wrong caret position; changed it to use the numeric quick-add control and verified editing history, clearing, pass/fail logging, and persistence in a passing targeted rerun. Logs: `build/dayinink-tracking-ui-tests.log`, `build/dayinink-tracking-history-retest.log`.
- 2026-11-02: Sift's 15 logging tests passed. Log: `build/device-sift-refresh-tests.log`. Signed device builds of both apps succeeded. Xcode initially reused profiles expiring November 4; moved only the three matching cached profiles into `build/provisioning-backup-2026-11-02/` and regenerated them using automatic signing. New DayInInk, Sift, and SiftFilter profiles expire November 9 at approximately 14:41 America/Chicago. Build logs: `build/device-dayinink-renew-build.log`, `build/device-sift-renew-build.log`.
- 2026-11-02: Began English-language DayInInk naming discovery. Public App Store listings already use DayInInk for habit trackers. Documented evidence, rejected alternatives, and the initial Little Kept / Morrowmarks candidates in `docs/release/NAMING_RESEARCH.md`. Name selection and App Store Connect availability checks remain open; no app records or domains were reserved.
- 2026-11-02: Successfully installed the refreshed Sift (including SiftFilter) and DayInInk builds on Michael's iPhone 16 Pro using devicectl. Both retain the existing bundle IDs, version 1.0.0 / build 1, and app data containers. Installation results: `build/device-sift-refresh-install.json`, `build/device-dayinink-refresh-install.json`. These builds include Sift keyword-only Activity and DayInInk export/import plus editable tracking types. Fresh physical-device feature acceptance remains pending.
- 2026-11-02: Added a per-habit Daily default selector (Passed/true or Failed/false) for creating and editing pass/fail habits. Older saves/backups without the new setting retain Passed. Unrecorded days use the selected default; explicit history is preserved and clearing restores the default. Updated Today status, detail/trend explanations, backup tests, and support/listing drafts. All 22 core/backup tests and the complete 10-case simulator UI suite passed. Logs: `build/dayinink-default-core-tests.log`, `build/dayinink-default-ui-tests.log`. Rebuilt and installed the final DayInInk device build; result: `build/device-dayinink-default-install.json`, build log: `build/device-dayinink-default-build.log`. Its profile still expires November 9 at 14:41 Central. Physical-device feature acceptance remains pending.
- 2026-11-02: Applied Day in Ink and Blotter branding, including Blotter's extension display name and Settings setup text, habit backup screens/filename, accessibility labels, and support/privacy drafts. Retained schemes, bundle IDs, habit data paths, shared preference suites, and Keychain identifiers. Advanced all targets to build 2 and regenerated the project. Both signed builds succeeded; verified product names, bundle IDs, version 1.0.0 / build 2, and profiles expiring November 9 around 14:41 Central. The renamed habit app's focused backup export/restore UI test passed. Successfully installed both builds on Michael's iPhone 16 Pro. The physical-device launch check for Blotter was rejected because the phone was locked, so launch and Settings-label acceptance remain pending. Build logs: `build/device-day-in-ink-build.log`, `build/device-blotter-build.log`; UI log: `build/day-in-ink-branding-ui-tests.log`; install results: `build/device-day-in-ink-install.json`, `build/device-blotter-install.json`. App Store Connect availability is still unconfirmed.
- 2026-11-03: Completed the user-requested removal of Blotter Activity and installed version 1.0.0 / build 3 on Michael's iPhone 16 Pro. Removed the tab/view, all history record/read/retention code, and the old log-pull script. The extension no longer has an explicit shared Keychain entitlement or Keychain calls; the app retains only scoped deletion of both old services. Upgrade cleanup also removes legacy app/shared/private log files and the obsolete marker while preserving keywords, matching options, and setup. The 13 filtering/deletion-migration tests passed on November 2; signed device build succeeded. Verified build 3 binaries have no Keychain add/read/update calls and no delete call in the filter. Updated privacy/support/listing drafts and added the release-preparation explanation. Logs: `build/blotter-cleanup-tests.log`, `build/device-blotter-cleanup-build.log`; install result: `build/device-blotter-cleanup-install.json`. Automated launch was blocked by the phone's locked state; open Blotter to run app cleanup and trigger the filter for its private legacy-file cleanup. No real-message validation of build 3 is claimed.
- 2026-11-03: Fixed the simulator build workflow that caused Blotter's “Couldn’t remove old activity” alert. Disabling signing omitted simulated Keychain entitlements; isolated deletion probes returned `errSecMissingEntitlement` (-34018), including without an access-group constraint. Simulator build/UI-test commands now use ad-hoc signing rather than disabling signing. `make build APP=Sift` succeeded; the built runtime group and simulated entitlement agree, and the installed app launched without the cleanup alert. All 13 Blotter matching/cleanup tests passed. Production deletion scoping and failure reporting/retry are unchanged; signed physical-device upgrade validation remains separate.
- 2026-11-03: Implemented the requested application fixes and renamed Blotter's app/extension bundle IDs to `com.droessmj.blotter` / `com.droessmj.blotter.filter`, intentionally preserving shared rules and legacy deletion identifiers. HabitKit's 36 tests and Blotter's 13 tests passed; both simulator builds and unsigned Release archives succeeded. All 11 permanent Day in Ink UI scenarios passed across the main run and a targeted two-test rerun after correcting test caret placement and removing incidental numeric-format assertions. Four temporary runtime smoke scenarios passed: future-date history, explicit Buddhist legacy migration/relaunch, Day in Ink policy navigation, and Blotter large-text onboarding/persistent policy navigation. Results: `build/ReleaseFixes-UI.xcresult`, `build/ReleaseFixes-Numeric-Retest.xcresult`; temporary smoke source is removed after verification. Prepared and validated `APP_STORE_CONNECT.json`; live record creation is blocked on Apple authentication, not marked complete. Updated app/support/privacy guidance; no upload or website deployment was performed.
- 2026-11-03: Built and development-signed the latest Day in Ink (`com.droessmj.dayinink`) and new Blotter (`com.droessmj.blotter`, embedded `com.droessmj.blotter.filter`) and installed both on the connected iPhone 16 Pro without uninstalling existing apps. Device inventory confirms version 1.0.0 / build 3 for both and the retained Blotter App Group. Code signatures and profiles were verified: Day in Ink profile expires November 9 at 20:41 UTC; Blotter app/filter profiles expire November 10 around 19:33 UTC. Day in Ink launch was denied because the phone was locked; no retry or successful on-device runtime/feature validation is claimed. Open the apps after unlocking, confirm the original calendar if Day in Ink requests migration, and explicitly select the new Blotter filter. Install/device evidence: `build/phone-release-fixes-*-install.json`, `build/phone-release-fixes-*-info.json`; launch failure: `build/phone-release-fixes-dayinink-launch.json`.
