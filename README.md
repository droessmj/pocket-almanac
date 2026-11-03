# Pocket Almanac

Personal iPhone apps, built primarily for my own use and shared in case others find them useful. A native SwiftUI monorepo with independently installable apps:

| App | Purpose | Minimum iOS |
| --- | --- | --- |
| [Blotter](apps/Sift) | On-device SMS keyword filter | 26 |
| [Day in Ink](apps/DayInInk) | Daily pass/fail and progress habits, with per-habit trends | 17 |

App Store titles are **Blotter: Message Filter** and **Day in Ink: Habit Tracker**. Xcode schemes and source paths are Sift and DayInInk. Blotter uses `com.droessmj.blotter` and `com.droessmj.blotter.filter`; its legacy App Group and cleanup Keychain identifiers are intentionally retained. This is a new app identity, not an update to the old Sift bundle. Day in Ink now uses `com.droessmj.dayinink` with private storage.

```text
apps/
  Sift/            # Existing app, message filter extension, and Sift-only shared code
  DayInInk/        # Habit tracker, assets, and UI tests
packages/
  HabitKit/        # Tracking models, persistence, calendar logic, and unit tests
Config/            # Shared signing configuration
scripts/           # App icon generation
project.yml        # XcodeGen source of truth for all targets and schemes
```

The generated project keeps the name `Sift.xcodeproj`. App targets have separate bundle IDs and data containers.

## Build

Requires Xcode 26+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

1. Set your Apple team ID in `Config/Team.xcconfig`.
2. `xcodegen generate`
3. Open `Sift.xcodeproj`, choose the **Sift** or **DayInInk** scheme, select your iPhone or simulator, and run.

For Blotter (Sift scheme), enable Settings → Apps → Messages → Text Message Filter → Blotter on your iPhone. Eligible texts from unknown senders that contain a keyword go silently to Junk. Only keyword rules, matching options, and setup status are saved; there is no Activity tab or match history. Upgrade cleanup deletes previously stored logs. See [Blotter's README](apps/Sift/README.md) for migration and device checks.

For Day in Ink (DayInInk scheme), six starter habits are included with no fabricated history. Customize them or create your own. Tap a habit’s + button to add progress, or its check-in button to change its pass/fail result. Open a habit to log a failure, adjust a daily total, edit history, or view 7-, 30-, and 90-day trends. Touch and hold a daily card for more actions.

## Checks

```sh
make test-core             # Calendar, progress, check-in, streak, and storage tests
make test-sift             # Keyword matching and deletion-only upgrade cleanup tests
make build APP=DayInInk    # Simulator build
make build APP=Sift       # Includes the SMS filter extension
make test-ui              # DayInInk’s end-to-end simulator tests
make archive-check APP=DayInInk # Unsigned Release packaging check; use APP=Sift for Sift
```

`make test-ui` uses the iPhone 18 Pro simulator by default. Set `TEST_DESTINATION='platform=iOS Simulator,name=…'` to use another installed iPhone simulator. UI tests use isolated storage and preserve the app’s ordinary data.

To add another app, put its files in `apps/<Name>`, add an application target and scheme in `project.yml` with a distinct bundle ID, then regenerate. Put reusable code in local Swift packages under `packages/`; keep app-specific code with its app.

## Release

Track preparation, validation, and launch in [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md). Public support and privacy content is maintained in [website/src](website/src/). Root docs/ material is kept outside version control.

Copy-ready app-record and listing fields are prepared in [APP_STORE_CONNECT.json](APP_STORE_CONNECT.json), including SKUs, language, URLs, descriptions, keywords, review notes, and TestFlight instructions. These are local preparation, not live records: authenticated App Store Connect access, exact-name/SKU acceptance, private review phone details, screenshots, and signed uploads remain account/release tasks.

The GitHub Pages support website is in [website/](website/README.md). Open [the built home page](website/dist/index.html) for a local preview. It includes separate support and privacy pages for Day in Ink and Blotter, links to this repository’s Issues tab, and offers `app-support@droessmj.com` for private questions. The prepared Pages workflow deploys only when manually run. Publication is a separate step.

Review the release checklist for outstanding publication checks. See [SECURITY.md](SECURITY.md) for private vulnerability reporting.

1. Set the paid Apple Developer team ID in `Config/Team.xcconfig`.
2. `xcodegen generate`
3. Choose the app’s scheme and a physical-device destination. In Xcode: Product → Archive → Distribute App → App Store Connect.

## Support development

If these apps are useful to you, you can [leave a one-time tip on Ko-fi](https://ko-fi.com/droessmj). No subscription required.
Contributions are optional and do not unlock app features, grant commercial-use rights, or guarantee features, release dates, or support response times.

## License

Copyright (c) 2026 Michael Droessler.

Sift is licensed under the [PolyForm Noncommercial License 1.0.0](LICENSE). You may use, modify, and share it for
personal and other noncommercial purposes. Charities, schools, public research organizations, and government
institutions may also use it.

**Commercial use requires a separate license.** That includes selling Sift or derivatives, offering it as part of
a paid product or service, or using it in a business. To ask about commercial licensing, open an issue in this
repository or contact the copyright holder.
