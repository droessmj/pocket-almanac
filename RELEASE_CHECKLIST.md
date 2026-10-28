# App Store release checklist

Release Daymark and Sift as separate iPhone apps under the same developer account. Start with Daymark in TestFlight. Sift's message filter extension is embedded in Sift, with no separate store listing.

Check a task only when its result has been verified. Local build checks do not establish paid membership, provisioning, or App Review approval.

Next input needed: confirm paid Apple Developer membership and the configured team, and supply the public support contact and website/domain (or confirm that a website still needs to be set up). Sift's logging mechanics are fixed and regression-tested. Signing, public links, shared-keychain release review, and physical-device validation remain open. The user will perform device checks using `apps/Sift/README.md`.

## 1. Developer account and signing

- [x] Confirm separate application targets, bundle IDs, icons, and schemes exist. Both icons are 1024 × 1024 with no alpha channel.
- [x] Confirm Xcode and XcodeGen are installed (Xcode 27.1; XcodeGen available).
- [x] Confirm a team ID is configured in `Config/Team.xcconfig` (`VGRQY536X3`).
- [ ] Confirm the configured team has active paid Apple Developer Program membership.
- [ ] Confirm Xcode is signed in to that team and can create distribution signing assets. The initial command-line identity check reported zero valid identities; verify in Xcode before treating this as a signing failure.
- [ ] Confirm bundle IDs are registered: `com.droessmj.daymark`, `com.droessmj.sift`, and `com.droessmj.sift.filter`.
- [ ] Confirm Sift's app and extension provisioning support App Group `group.com.droessmj.sift` and their shared keychain group.

## 2. Privacy and support

- [ ] Choose a public support contact and permanent HTTPS URLs.
- [x] Prepare privacy/support drafts in `docs/release/PRIVACY_AND_SUPPORT.md`.
- [ ] Review the draft privacy and support content in `docs/release/`.
- [ ] Publish the approved privacy policies and support content; verify every URL works publicly without login.
- [ ] Add accessible privacy-policy and support links inside both apps.
- [ ] Inspect each release archive's privacy report and bundled manifests.
- [ ] Complete App Store Connect privacy answers against the final build and all SDKs. On-device-only processing may qualify for "Data Not Collected"; do not equate local storage with off-device collection.

## 3. Sift filtering and activity log

- [ ] Resolve whether the shared-keychain activity log is supported under IdentityLookup's privacy restrictions; do not treat a successful build as confirmation.
- [x] Align retention and deletion behavior with the privacy policy and UI. Cleanup runs on writes, app activation, and reads; no new plaintext fallback is written. Old private fallback files are removed when the updated extension next starts. Read/delete failures are reported, and failed reinstall wipes retry.
- [x] Ensure users understand that sender, timestamp, verdict, and matched keyword are saved locally, even though full message bodies are not saved (setup and Activity copy updated).
- [ ] Verify filtering and activity logging with real unknown-sender messages, a locked phone, and the app closed. User will verify; steps are in `apps/Sift/README.md`. Confirm Clear stays cleared after relaunch and that new messages still create new entries.
- [ ] Verify matching/nonmatching keywords, case, accents, whole-word options, Contacts, and iMessage exclusions.
- [ ] Verify the Settings setup instructions on the supported iOS version.

## 4. Build and test

- [x] Run `make test-core` (12 tests passed on 2026-10-28).
- [x] Run `make test-sift` (14 logging regression tests passed on 2026-10-28).
- [x] Build Daymark for the simulator (2026-10-28).
- [x] Run Daymark UI tests using isolated test storage (4 tests passed on iPhone 18 Pro / iOS 27.0 on 2026-10-28).
- [x] Build Sift and its extension for the simulator (2026-10-28).
- [x] Run `make archive-check APP=Daymark` and `make archive-check APP=Sift` to check unsigned Release packaging. Verified iPhone-only device family, version/build values, app icons, dSYMs, manifests, and the embedded Sift extension. These archives cannot be uploaded as distribution builds.
- [ ] Test Daymark on a real iPhone: creation, progress, pass/fail, history edits, archive/restore/delete, relaunch persistence, date changes, and larger text.
- [ ] Test supported older and current iOS versions. Daymark targets iOS 17+; Sift targets iOS 26+.
- [ ] Validate signed distribution archives with an Apple-accepted release of Xcode.

## 5. Store records and listing assets

- [ ] Confirm available display names and create separate App Store Connect records using the existing app bundle IDs.
- [ ] Choose free or paid pricing, territories, and launch availability. If charging, finish applicable agreements, tax, and banking setup.
- [x] Prepare listing descriptions, screenshot plans, and reviewer instructions in `docs/release/STORE_LISTINGS.md`.
- [x] Save initial Daymark screenshot candidates (Today, Trends, habit detail) from the passing UI tests in `docs/release/screenshots/Daymark/`.
- [ ] Review the draft listing descriptions and reviewer instructions in `docs/release/STORE_LISTINGS.md`.
- [ ] Capture current, accurate iPhone screenshots for each app using synthetic personal data.
- [ ] Finish category, age rating, content rights, privacy, export compliance, and other required App Store Connect fields.
- [ ] Enter public support/privacy URLs and private App Review contact details.

## 6. Signed upload and TestFlight

- [x] Set initial version/build numbers (both archives verified as version 1.0.0, build 1). Increase build numbers for subsequent uploads.
- [x] Generate the project with `xcodegen generate`; regenerate after future configuration changes.
- [ ] Archive Daymark in Xcode for Any iOS Device; validate and upload to App Store Connect.
- [ ] Invite Daymark testers; review crashes and feedback; fix release-blocking issues.
- [ ] Archive, validate, and upload Sift after its logging and device checks are complete.
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
