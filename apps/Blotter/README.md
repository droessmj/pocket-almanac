# Blotter

App Store title: **Blotter: Message Filter**. The app uses bundle ID `com.droessmj.blotter`, and its embedded filter uses `com.droessmj.blotter.filter`. The Xcode scheme and source directory are named Blotter.

On-device SMS/MMS keyword filtering for iPhone on iOS 26+. Build the Blotter scheme in `Blotter.xcodeproj`; its IdentityLookup extension is embedded automatically.

## Setup and shared rules

A fresh installation shows onboarding. In iPhone Settings, go to Apps → Messages → Text Message Filter and choose Blotter. Completing onboarding or adding keywords does not activate the filter; the app cannot confirm the system selection. Concise enablement instructions remain visible on Keywords after onboarding.

The app and filter share App Group `group.com.droessmj.blotter`. Only configured keywords, matching options, and onboarding completion are saved. Both targets require this App Group authorization. The filter reads the incoming body to match rules, does not access the sender field, and does not save messages, match events, or message metadata. There is no activity history, activity logging, or Keychain access.

Native Help & Support and Privacy Policy links are available during onboarding and on Keywords. Onboarding scrolls to keep instructions, the Get started button, and links reachable at accessibility text sizes.

Matching defaults to ignoring case and accents, with whole words only. With Match case enabled, `vote` matches lowercase `vote`, not `Vote`. Turning Whole words only off also allows lowercase `vote` inside `devoted`.

## Checks

```sh
make test-blotter
make build APP=Blotter
make archive-check APP=Blotter
```

Simulator builds use ad-hoc signing (`CODE_SIGN_IDENTITY=-`) to supply the App Group entitlement. `archive-check` checks unsigned device packaging; it is not a runnable simulator build or a distributable archive.

Tests cover case/accent/whole-word matching, case-sensitive substring examples, searching beyond embedded nonmatches, phrases, empty input, and rule order. These do not replace signed-device validation.

On your iPhone:

1. Install Blotter with authorization for `group.com.droessmj.blotter`. Confirm onboarding appears on a fresh installation.
2. Select Blotter under Settings → Apps → Messages → Text Message Filter. Confirm enablement instructions remain visible on Keywords without claiming the filter is active.
3. Add `pineapple`. Send an eligible unknown-sender SMS/MMS containing `pineapple offer`; verify Junk classification.
4. Send `hello there`; verify Blotter does not classify it. Neither message should create history.
5. Repeat after closing Blotter and locking the phone (unlock once after reboot first).
6. Verify case/accent/whole-word options and Contacts/iMessage exclusions.
7. Open Help & Support and Privacy Policy from onboarding and Keywords. At accessibility text sizes and in landscape, scroll through onboarding and confirm all instructions, controls, and links remain reachable.

See Apple’s [IdentityLookup guidance](https://developer.apple.com/documentation/identitylookup/sms-and-mms-message-filtering) for message eligibility and extension restrictions.
