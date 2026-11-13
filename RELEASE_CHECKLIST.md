# App Store release checklist

Release **Day in Ink: Habit Tracker** and **Blotter: Message Filter** as separate iPhone apps. Start with internal Day in Ink TestFlight testing. Blotter's embedded filter has no separate listing.

Check a task only after verifying its result. Local builds do not establish membership, distribution signing, processed uploads, or App Review approval.

## Current release contract

- Only current version 3 app state is supported; no calendar conversion, old App Group continuity, Keychain deletion, or other in-app migration runs. The older `com.droessmj.daymark` development app has a separate sandbox and exports version 2 backups, which cannot be imported directly into the current app.
- Day in Ink uses version 3 backups, decimal numeric values, and persisted Gregorian civil start/day keys. Unsupported or invalid files are rejected without replacing existing data. Writes run off the main actor in submission order; memory changes only after persistence succeeds.
- Blotter uses `com.droessmj.blotter`, embedded `com.droessmj.blotter.filter`, and App Group `group.com.droessmj.blotter`. Neither target requires shared Keychain access. No message/match history is recorded.
- Google Analytics remains on the website home page only. The four support/privacy pages do not initialize analytics or set analytics cookies. Previously created parent-domain cookies may remain in a browser.
- Both apps are free, with manual release and distribution in all countries/regions where applicable compliance is complete. The selected names still require App Store Connect acceptance.

## 1. Developer account and signing

Apple Developer Program membership was reported **Active** on November 4, 2026. Team `VGRQY536X3` successfully development-signed Day in Ink for a physical iPhone and distribution-signed its version `1.0.0`, build `4` IPA with the explicit `com.droessmj.dayinink` profile. Xcode successfully uploaded that build to App Store Connect; the user subsequently reported installing it through TestFlight. Browser automation is not authenticated; remaining account and regional compliance checks still require review.

- [ ] Confirm active paid Apple Developer Program membership, App Store Connect access, current agreements, and appropriate roles.
- [ ] Confirm the intended team in `Config/Team.xcconfig` and create/authorize distribution signing assets.
- [ ] Register/confirm `com.droessmj.dayinink`, `com.droessmj.blotter`, and `com.droessmj.blotter.filter`.
- [ ] Authorize App Group `group.com.droessmj.blotter` for both Blotter targets. No old group or Keychain capability is needed.
- [ ] Inspect final signed app/extension entitlements and matching version/build values.
- [ ] Use an Apple-accepted Xcode release. Set `DEVELOPER_DIR` to the Xcode app when command-line selection points only at Command Line Tools.

## 2. Local release hardening and verification

- [x] Run HabitKit tests, including exact fractional completion, timezone-stable history, current-format rejection, bounds, and failed-save preservation.
- [x] Run Blotter matcher tests.
- [x] Verify queued Day in Ink edits, error propagation, disk/in-memory consistency, and recovery imports with the actual store.
- [x] Build both simulator apps and run Day in Ink UI scenarios.
- [x] Exercise small numeric presentation, localized input, maximum text size, and narrow-screen navigation.
- [x] Verify save failures remain visible above open editors and do not dismiss or discard input.
- [x] Produce fresh unsigned Release archives for both apps and inspect bundle IDs, OS/device family, icons, manifests, and dSYMs. These packaging checks are not distributable archives.
- [x] Build/check the static website and verify analytics runs on home only in a real browser.
- [x] Critically review the complete change set for correctness, concurrency, privacy, and regression risks before committing.

## 3. Signed-device and supported-OS acceptance

Day in Ink targets iOS 17+; Blotter targets iOS 26+. Simulator and host tests do not establish the following:

- [ ] Install current signed builds and verify fresh launch, save/relaunch, and actual TestFlight installation later.
- [ ] Day in Ink: repeated fractional quick-add, very small values, localized entry, pass/fail defaults, tracking changes with recorded history, and rapid edits.
- [ ] Day in Ink: export, cancelled import, confirmed restore, unsupported/corrupt backup rejection, and relaunch persistence.
- [ ] Day in Ink: timezone travel, midnight, calendar-preference changes, clock rollback/future start dates, and representative large accepted archives.
- [ ] Both apps: VoiceOver, maximum Dynamic Type, small screens, reachable support/privacy links, and error feedback.
- [ ] Blotter: select it explicitly under Settings → Apps → Messages → Text Message Filter. Onboarding acknowledgment does not verify activation.
- [ ] Blotter: eligible unknown-sender SMS/MMS matches/nonmatches, case/accent/whole-word rules, and add/delete/edit options reaching the extension without reinstalling.
- [ ] Blotter: Contacts/iMessage exclusions and locked-phone filtering after the first unlock following reboot.
- [ ] Test the oldest supported OS/device configurations as well as current iOS. Only iOS 27 simulator runtime availability was established during the audit.

## 4. Public support, privacy, and repository safety

Public contact: `app-support@droessmj.com`; ordinary support uses `https://github.com/droessmj/pocket-almanac/issues` with synthetic examples only.

- [ ] Deploy the reviewed `website/dist/` using the manual Pages workflow; verify all five served pages against local content after deployment.
- [ ] Confirm support mailbox delivery, public issue access, and permanent support/privacy URLs.
- [ ] Verify HTTP upgrades to HTTPS and the default Pages URL redirects to the HTTPS custom domain. Both redirects passed the November 4 audit; verify again after publication changes.
- [ ] Confirm the native app privacy answers against final binaries/SDKs. Source supports "Data Not Collected"; on-device storage is not off-device collection.
- [ ] Inspect final signed archive privacy reports and bundled manifests, including the filter's App Group UserDefaults reason.
- [ ] Complete GitHub-side retained-copy cleanup for removed private docs and old root-Jekyll artifacts. Previously available connector access could not purge retained objects; private instructions are in ignored `build/docs-history-removal/HOSTED_CLEANUP.md`.
- [ ] Resolve or explicitly accept previously published schedule/commit metadata disclosures and retained historical copies. Removal from current source does not remove third-party copies.

The user's acceptance of full names in source/copyright/license notices remains unchanged. Never publish signing private keys, profiles, device logs, or personal app/backup data.

## 5. Store records and assets

Copy-ready values are in `APP_STORE_CONNECT.json`; they are not proof that live records exist.

- [ ] Confirm exact names/SKUs and create the two records.
- [ ] Review current descriptions, categories, keywords, privacy/support/marketing URLs, copyright, and reviewer instructions against shipping builds.
- [ ] Supply private review phone/contact details and confirm Apple mail delivery.
- [ ] Capture current accepted-size iPhone screenshots using synthetic data; show actual functionality, with no obsolete Activity screen.
- [ ] Complete age rating, content rights, export compliance, current medical/digital-goods questionnaires where applicable, and other required fields.
- [ ] Complete EU trader and applicable regional compliance declarations before enabling those territories.
- [ ] Apply free pricing, permitted territories, and manual release. Review Mac/Apple Vision Pro availability explicitly rather than assuming iPhone target settings settle storefront distribution.
- [ ] If submission extends past November 16, complete Apple's added age-rating descriptors; all apps need those declarations by January 12, 2027.

## 6. TestFlight, review, and launch

- [ ] Select a build number not already used for the same version and regenerate the project after configuration changes.
- [ ] Archive Day in Ink with distribution signing; validate/upload and confirm successful processing.
- [ ] Complete beta contacts/instructions, invite internal testers, review crashes/feedback, and resolve blockers.
- [ ] Archive/validate/upload Blotter, with reproducible SMS setup and keyword review instructions.
- [ ] Test the processed TestFlight binaries on physical devices. External testing requires TestFlight App Review.
- [ ] Select tested builds, submit each listing for App Review, resolve feedback, and manually release approved versions.
- [ ] Check live listings, install/first-launch flows, support/privacy links, and post-release crash reports.

## References

- [Apple submission workflow](https://developer.apple.com/app-store/submitting/)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Current upload requirements](https://developer.apple.com/news/upcoming-requirements/)
- [App privacy definitions](https://developer.apple.com/app-store/app-privacy-details/)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/)
- [IdentityLookup message filtering](https://developer.apple.com/documentation/identitylookup/sms-and-mms-message-filtering)
- [November 2026 age-rating changes](https://developer.apple.com/news/?id=yxkh08us)

## Verification log

- November 4, 2026 audit baseline: 36 HabitKit tests, 13 Blotter matcher/cleanup tests, and 11 Day in Ink UI tests passed. Both unsigned Release archives succeeded with Xcode 27.2 / iOS 27.2 SDK. Targeted probes nevertheless reproduced fractional-completion and timezone-history defects. This baseline predates current-state hardening and is not acceptance of the changed code.
- November 4, 2026 Blotter naming cutover: project, schemes, app/extension targets, source directory, entry point, and shared test package now use Blotter naming. Bundle IDs and App Group are unchanged. All 9 current matcher tests passed; Blotter and Day in Ink simulator builds succeeded; Blotter installed, launched, and displayed onboarding on the iPhone 18 Pro simulator. A development-signed Release archive succeeded at `build/archives/Blotter.xcarchive`, with signing team `VGRQY536X3` and the embedded filter validated. Website readiness checks passed for all five pages. App Store distribution validation, upload, and physical-device SMS checks were not performed.
- November 4, 2026 current-state hardening: all 42 HabitKit tests, 9 current Blotter matcher tests, and 14 Day in Ink UI scenarios passed. A separate iPhone SE simulator run passed logging, period selection, and navigation at maximum Dynamic Type; card and row labels use non-truncating wrapping, and scroll-depth screenshots are exported under `build/HardeningFinalVisualAttachments` for manual review. Simulator runtime was iOS 27.0, with Xcode 27.2 / iOS 27.2 SDK. This does not validate minimum supported OS versions or a physical device.
- Actual-store probes passed ten queued `0.1` increments reaching exactly `1`, invalid-record rejection, real filesystem save-failure propagation with unchanged memory and disk, recovery/reload, stale-edit resolution, duplicate Archive actions remaining archived, and rejection of an unrepresentable increment without silently rounding away the addition. A UI probe confirmed the local failure alert preserves editor input and retry succeeds after filesystem write access is restored.
- Blotter launched on the small-screen simulator at maximum text size; onboarding, adding a keyword, and changing a matching option remained reachable and persisted across relaunch. The current shared App Group container resolved in the simulator. Actual incoming-message filtering and distribution entitlements remain physical-device/signing gates.
- On an optimized host smoke fixture of 100 habits and 36,500 entries (10.84 MB), generating 90-day samples for all habits took approximately 0.031 seconds with indexed lookups versus 0.748 seconds before indexing. These are host measurements, not iPhone performance results.
- Fresh unsigned Release archives for both apps succeeded at version `1.0.0`, build `4`, with the expected iPhone-only device family, deployment targets, icons, privacy manifests, embedded Blotter filter, and dSYMs. Day in Ink was re-archived after the final numeric and accessibility changes. App Store distribution validation and upload were not performed.
- Website readiness checks passed all five pages. A real browser observed no scripts, analytics requests, fresh analytics cookies, or horizontal overflow on the four support/privacy pages; home-page analytics remained active. Existing home/parent-domain cookies remain as disclosed. Generated files are updated locally; the website has not been published.
- November 4, 2026 Day in Ink TestFlight milestone: the user created the explicit `com.droessmj.dayinink` identifier and app record, then Xcode distribution export and upload succeeded for version `1.0.0`, build `4`. Signature verification confirmed Apple Distribution signing, an exact application identifier, `get-task-allow = false`, and TestFlight reporting enabled; app and dSYM UUIDs matched. The upload service acknowledged processing, and the user later reported a TestFlight installation. No App Review submission or public release was performed.
- November 13, 2026 starter-habit update: fresh archives now contain only Walk (10,000 steps), Drink Water (8 glasses), and Workout (pass/fail). All 43 HabitKit tests and all 14 Day in Ink UI scenarios passed, including backup restore, per-habit defaults, tracking-mode history preservation, localized exact values, relaunch persistence, and maximum Dynamic Type navigation. Today and Workout detail screenshots were inspected. Existing archives are not reseeded. Repository build number is now `5`; it has not been uploaded. Tracking-history behavior changes and one-off legacy backup conversion remain pending user decisions; no phone data was changed.
