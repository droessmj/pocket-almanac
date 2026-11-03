# Blotter

Previously called Sift. The Xcode scheme, source paths, bundle IDs, and shared preferences retain their original names so installed updates preserve keyword rules and setup. App Store title: **Blotter: Message Filter**.

On-device SMS/MMS keyword filtering for iPhone on iOS 26+. Build the Sift scheme in `Sift.xcodeproj`; its IdentityLookup extension is embedded automatically.

The app opens directly to Keywords after setup. There is no Activity tab or match history. Only configured keywords, matching options, and setup status are saved. The filter reads the incoming body to match rules, does not access the sender field, and does not save messages, match events, or message metadata.

## Upgrade cleanup

On app activation, deletion-only migration removes both old Keychain services (`com.droessmj.sift.activity` and `com.droessmj.sift.keyword-history`), old app/shared `activity.jsonl` files, and the obsolete installation marker. It never reads or decodes old records. Keyword rules, matching options, and setup status are preserved. Failures are reported in the app and retried on activation.

The containing app retains the old Keychain access group only to delete old data. The filter has no explicit shared Keychain entitlement and does not compile the Keychain cleanup helper. It only attempts to delete its own private `Documents/activity.jsonl` at extension launch; a generic cleanup diagnostic omits message and keyword content. The app cannot reach that private extension container. Triggering the updated filter completes that part of an upgrade. Old backups and developer-exported copies are managed separately.

## Checks

```sh
make test-sift
make build APP=Sift
make archive-check APP=Sift
```

Tests cover case/accent/whole-word matching, phrases and nonmatches, scoped deletion of both old services, missing entitlements, file cleanup, retry after failures, and preservation of keyword preferences. These do not replace signed-device validation.

On your iPhone:

1. Open the updated Blotter build; confirm Keywords opens directly and saved rules/options remain.
2. Select Blotter under Settings → Apps → Messages → Text Message Filter.
3. Add `pineapple`. Send an eligible unknown-sender SMS/MMS containing `pineapple offer`; verify Junk classification.
4. Send `hello there`; verify Blotter does not classify it. No history should be created by either message.
5. Repeat after closing Blotter and locking the phone (unlock once after reboot first).
6. Verify case/accent/whole-word options and Contacts/iMessage exclusions.
7. If upgrading, open the app to delete old shared history and trigger the filter to clean its old private log. Any app cleanup failure should be reported and retry on the next activation.

See Apple’s [IdentityLookup guidance](https://developer.apple.com/documentation/identitylookup/sms-and-mms-message-filtering) for message eligibility and extension restrictions.
