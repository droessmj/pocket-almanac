# Blotter

Previously called Sift. App Store title: **Blotter: Message Filter**. Blotter uses app bundle ID `com.droessmj.blotter` and embedded filter bundle ID `com.droessmj.blotter.filter`. This is a new app identity, not an in-place update of the old Sift app. The Sift scheme and source paths stay unchanged.

On-device SMS/MMS keyword filtering for iPhone on iOS 26+. Build the Sift scheme in `Sift.xcodeproj`; its IdentityLookup extension is embedded automatically.

The app opens directly to Keywords after setup. Native Help & Support and Privacy Policy links are available both during setup and in the persistent Keywords screen. Setup scrolls to keep instructions, the Get started button, and links reachable at accessibility text sizes. There is no Activity tab or match history. Only configured keywords, matching options, and setup status are saved. The filter reads the incoming body to match rules, does not access the sender field, and does not save messages, match events, or message metadata.

## Identity, shared rules, and legacy cleanup

The app and filter intentionally retain App Group `group.com.droessmj.sift`. When both identities are signed by the same team with access to that group, existing shared keyword rules, matching options, and setup status remain available to Blotter. This is shared-container continuity, not migration of either app’s private container. Install Blotter and explicitly select it again under Settings → Apps → Messages → Text Message Filter; the old Sift filter selection does not transfer to the new extension identity. If shared setup status already exists, Blotter opens directly to Keywords.

On app activation, deletion-only cleanup removes accessible records in the old Keychain services (`com.droessmj.sift.activity` and `com.droessmj.sift.keyword-history`), `activity.jsonl` in the current app’s Documents directory and the shared App Group, and the obsolete shared installation marker. It never reads or decodes old records. Keyword rules, matching options, and setup status are preserved. Failures are reported in the app and retried on activation. The legacy Keychain access group remains intentionally unchanged and requires the same team’s signing authorization.

The filter has no explicit shared Keychain entitlement and does not compile the Keychain cleanup helper. It only attempts to delete its own private `Documents/activity.jsonl` at extension launch; a generic cleanup diagnostic omits message and keyword content. Blotter’s new app and extension identities do not automatically inherit or gain access to the old Sift app’s or extension’s private containers. Launching Blotter or triggering its filter cannot clean those old private containers; any cleanup there must be performed by a build retaining the corresponding old identity. Old backups and developer-exported copies are managed separately.

## Checks

```sh
make test-sift
make build APP=Sift
make archive-check APP=Sift
```

Simulator builds use ad-hoc signing (`CODE_SIGN_IDENTITY=-`) so Xcode supplies the App Group and Keychain entitlements. Do not launch builds made with `CODE_SIGNING_ALLOWED=NO`: simulator Keychain deletion returns `errSecMissingEntitlement` (-34018), even when no old record exists, and correctly triggers the cleanup error. Removing the access-group constraint does not fix missing authorization. `archive-check` remains unsigned because it checks device packaging only; it is not a runnable simulator build or a distributable archive.

Tests cover case/accent/whole-word matching, phrases and nonmatches, scoped deletion of both old services, missing entitlements, file cleanup, retry after failures, and preservation of keyword preferences. These do not replace signed-device validation.

On your iPhone:

1. Install Blotter with the same team and App Group authorization as Sift. If shared setup status exists, confirm Keywords opens directly and saved rules/options remain; otherwise complete setup.
2. Explicitly select Blotter under Settings → Apps → Messages → Text Message Filter, even if Sift was previously selected.
3. Add `pineapple`. Send an eligible unknown-sender SMS/MMS containing `pineapple offer`; verify Junk classification.
4. Send `hello there`; verify Blotter does not classify it. No history should be created by either message.
5. Repeat after closing Blotter and locking the phone (unlock once after reboot first).
6. Verify case/accent/whole-word options and Contacts/iMessage exclusions.
7. If coming from Sift, open Blotter to delete accessible old shared/Keychain history. Any cleanup failure should be reported and retry on the next activation. Do not expect old Sift private app or extension containers to transfer or be cleaned by Blotter.
8. Open Help & Support and Privacy Policy from setup and Keywords. At accessibility text sizes and in landscape, scroll through setup and confirm all instructions, controls, and links remain reachable.

See Apple’s [IdentityLookup guidance](https://developer.apple.com/documentation/identitylookup/sms-and-mms-message-filtering) for message eligibility and extension restrictions.
