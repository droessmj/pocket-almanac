# Sift

On-device SMS/MMS keyword filtering for iPhone on iOS 26+. Build the Sift scheme in `Sift.xcodeproj`; its IdentityLookup extension is embedded automatically.

## Activity storage

Activity saves sender, timestamp, verdict, and matching reason (which can include the matched keyword), never full message bodies. Each entry is a separate shared keychain item using `AfterFirstUnlockThisDeviceOnly` protection and no synchronization. This preserves independent records across app/extension writes. App Group preferences hold keyword settings; the filter does not write shared-container files.

Cleanup runs before and after writes, on app activation, and on log reads. It removes records older than 30 days, records beyond the newest 1,000, and unreadable payloads. A clock change backward preserves newer timestamps. Operations in each process are serialized; simultaneous app/extension operations may temporarily exceed the count, and the next cleanup reconciles it. Cleanup cannot run while both processes are inactive or storage is unavailable.

Logging finishes before the extension calls its completion handler. Failures are best effort and never change the filtering verdict. The Activity screen reports read/delete failures, keeps previously loaded entries visible on a failed refresh, and offers retry. A failed reinstall wipe does not mark the installation as cleaned.

No new plaintext fallback files are written. Legacy `Documents/activity.jsonl` files are removed in each process's own container. The extension performs this migration at startup and before log operations; the app cannot reach an old file inside the extension until the extension runs. Old exported copies and old backups must be managed separately.

For diagnostics, use the device Console: subsystem `com.droessmj.sift`, category `ActivityLog`. Only generic errors and OSStatus codes are logged. `scripts/pull-filter-log.sh` now explains this change instead of extracting message metadata.

## Automated checks

From the repository root:

```sh
make test-sift
make build APP=Sift
make archive-check APP=Sift
```

The Swift package compiles the actual shared source against an injectable storage boundary. Tests exercise retention, saturation, corruption, failures, migration, reinstall retries, concurrent writes, and pruning against a stale cross-process snapshot. They do not establish that the signed extension can access the shared keychain on a physical iPhone.

## Physical-device checks

1. Install the updated build and launch Sift. Enable it in Settings → Apps → Messages → Text Message Filter. Add `pineapple` with default matching settings.
2. From an unknown sender outside Contacts, send eligible SMS/MMS messages `pineapple offer` and `hello there`. Verify Junk classification for the first, no Sift classification for the second, and the corresponding activity reasons.
3. After unlocking the phone once since reboot, close Sift and lock the phone. Send another eligible matching message. Reopen Sift and confirm its verdict and activity. Before the first unlock after reboot, storage may be unavailable; logging must not prevent the filter from returning its verdict.
4. Clear activity, close and reopen Sift, and confirm prior entries stay gone. Send a new message and confirm only new activity appears. A failed deletion must show an error.
5. If upgrading from a development build that generated a fallback file, trigger the updated filter before checking that its private `Documents/activity.jsonl` has been removed.
6. Verify matching options, Contacts/iMessage exclusions, and the Settings instructions on your iOS release. Report the build, iOS version, and any numeric Console storage errors using made-up message examples.

Shared-keychain technical behavior and App Review acceptance are separate checks. Apple's [IdentityLookup documentation](https://developer.apple.com/documentation/identitylookup/sms-and-mms-message-filtering) prohibits extension writes to shared containers; the keychain design still needs release review.
