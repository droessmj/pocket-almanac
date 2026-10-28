# iPhone apps

A native SwiftUI monorepo with independently installable apps:

| App | Purpose | Minimum iOS |
| --- | --- | --- |
| [Sift](apps/Sift) | On-device SMS keyword filter, with recent activity history | 26 |
| [Daymark](apps/Daymark) | Daily pass/fail and progress habits, with per-habit trends | 17 |

```text
apps/
  Sift/            # Existing app, message filter extension, and Sift-only shared code
  Daymark/         # Habit tracker, assets, and UI tests
packages/
  HabitKit/        # Tracking models, persistence, calendar logic, and unit tests
Config/            # Shared signing configuration
scripts/           # Icon generation and Sift diagnostics
project.yml        # XcodeGen source of truth for all targets and schemes
```

The generated project keeps the name `Sift.xcodeproj`. App targets have separate bundle IDs and data containers.

## Build

Requires Xcode 26+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

1. Set your Apple team ID in `Config/Team.xcconfig`.
2. `xcodegen generate`
3. Open `Sift.xcodeproj`, choose the **Sift** or **Daymark** scheme, select your iPhone or simulator, and run.

For Sift, enable Settings → Apps → Messages → Text Message Filter → Sift on your iPhone. Texts from unknown senders that contain a keyword go silently to Junk. Its activity log stores sender, time, verdict, and a reason that can include the matched keyword; it never stores full message text. Cleanup runs on writes, app activation, and log reads, keeping up to 1,000 entries within a 30-day history. No plaintext fallback copies are created. See [Sift's README](apps/Sift/README.md) for storage behavior and device checks.

For Daymark, six starter habits are included with no fabricated history. Customize them or create your own. Tap a habit’s + button to add progress, or its check-in button to mark a pass. Open a habit to log a failure, adjust a daily total, edit history, or view 7-, 30-, and 90-day trends. Touch and hold a daily card for more actions.

## Checks

```sh
make test-core             # Calendar, progress, check-in, streak, and storage tests
make test-sift             # Logging retention, cleanup, failures, and concurrency tests
make build APP=Daymark    # Simulator build
make build APP=Sift       # Includes the SMS filter extension
make test-ui              # Daymark’s end-to-end simulator tests
make archive-check APP=Daymark # Unsigned Release packaging check; use APP=Sift for Sift
```

`make test-ui` uses the iPhone 18 Pro simulator by default. Set `TEST_DESTINATION='platform=iOS Simulator,name=…'` to use another installed iPhone simulator. UI tests use isolated storage and preserve the app’s ordinary data.

To add another app, put its files in `apps/<Name>`, add an application target and scheme in `project.yml` with a distinct bundle ID, then regenerate. Put reusable code in local Swift packages under `packages/`; keep app-specific code with its app.

## Release

Track preparation, validation, and launch in [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md). Privacy/support content and store listing drafts are in [docs/release](docs/release).

1. Set the paid Apple Developer team ID in `Config/Team.xcconfig`.
2. `xcodegen generate`
3. Choose the app’s scheme and a physical-device destination. In Xcode: Product → Archive → Distribute App → App Store Connect.

## License

Copyright (c) 2026 Michael Droessler.

Sift is licensed under the [PolyForm Noncommercial License 1.0.0](LICENSE). You may use, modify, and share it for
personal and other noncommercial purposes. Charities, schools, public research organizations, and government
institutions may also use it.

**Commercial use requires a separate license.** That includes selling Sift or derivatives, offering it as part of
a paid product or service, or using it in a business. To ask about commercial licensing, open an issue in this
repository or contact the copyright holder.
