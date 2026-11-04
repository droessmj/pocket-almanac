# Pocket Almanac

Personal iPhone apps, built primarily for my own use and shared in case others find them useful. A native SwiftUI monorepo with independently installable apps:

| App | Purpose | Minimum iOS |
| --- | --- | --- |
| [Blotter](apps/Blotter) | On-device SMS keyword filter | 26 |
| [Day in Ink](apps/DayInInk) | Daily pass/fail and progress habits, with per-habit trends | 17 |

App Store titles are **Blotter: Message Filter** and **Day in Ink: Habit Tracker**. Xcode schemes and source paths are Blotter and DayInInk. Blotter uses `com.droessmj.blotter`, `com.droessmj.blotter.filter`, and App Group `group.com.droessmj.blotter`, with no Keychain entitlement. Day in Ink uses `com.droessmj.dayinink` with private storage. Only the current data format is supported; there are no prior-release migrations.

```text
apps/
  Blotter/         # Message filter app, extension, and Blotter-only shared code
  DayInInk/        # Habit tracker, assets, and UI tests
packages/
  HabitKit/        # Tracking models, persistence, calendar logic, and unit tests
Config/            # Shared signing configuration
scripts/           # App icon generation
project.yml        # XcodeGen source of truth for all targets and schemes
```

The generated project is `Blotter.xcodeproj`. App targets have separate bundle IDs and data containers.

## Build

Requires Xcode 26+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

1. Set your Apple team ID in `Config/Team.xcconfig`.
2. `xcodegen generate`
3. Open `Blotter.xcodeproj`, choose the **Blotter** or **DayInInk** scheme, select your iPhone or simulator, and run.

For Blotter, enable Settings → Apps → Messages → Text Message Filter → Blotter on your iPhone. Eligible texts from unknown senders that contain a keyword go silently to Junk. Only keyword rules, matching options, and the setup acknowledgment are saved; there is no message or match history. Setup acknowledgment does not verify system activation. Enablement instructions remain available on Keywords. See [Blotter's README](apps/Blotter/README.md) for device checks.

For Day in Ink (DayInInk scheme), six starter habits are included with no fabricated history. Customize them or create your own. Tap a habit’s + button to add progress, or its check-in button to change its pass/fail result. Open a habit to log a failure, adjust a daily total, edit history, or view 7-, 30-, and 90-day trends. Touch and hold a daily card for more actions.

Day in Ink uses decimal progress values and stable Gregorian start/day keys. Its version 3 backups are the only accepted format. Saving runs off the main actor in submission order, with changes published only after successful persistence. Invalid or unsupported files are preserved rather than silently reset.

## Checks

```sh
make test-core             # Calendar, progress, check-in, streak, and storage tests
make test-blotter          # Keyword matching tests
make build APP=DayInInk    # Simulator build
make build APP=Blotter     # Includes the SMS filter extension
make test-ui              # DayInInk’s end-to-end simulator tests
make archive-check APP=DayInInk # Unsigned Release packaging check; use APP=Blotter for Blotter
```

`make test-ui` uses the iPhone 18 Pro simulator by default. Set `TEST_DESTINATION='platform=iOS Simulator,name=…'` to use another installed iPhone simulator. UI tests use isolated storage and preserve the app’s ordinary data.

To add another app, put its files in `apps/<Name>`, add an application target and scheme in `project.yml` with a distinct bundle ID, then regenerate. Put reusable code in local Swift packages under `packages/`; keep app-specific code with its app.

## Release

Track preparation, validation, and launch in [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md). Public support and privacy content is maintained in [website/src](website/src/). Root docs/ material is kept outside version control.

Copy-ready app-record and listing fields are prepared in [APP_STORE_CONNECT.json](APP_STORE_CONNECT.json), including SKUs, language, URLs, descriptions, keywords, review notes, and TestFlight instructions. These are local preparation, not live records: authenticated App Store Connect access, exact-name/SKU acceptance, private review phone details, screenshots, and signed uploads remain account/release tasks.

The GitHub Pages support website is in [website/](website/README.md). Open [the built home page](website/dist/index.html) for a local preview. It includes separate support and privacy pages for Day in Ink and Blotter, links to this repository’s Issues tab, and offers `app-support@droessmj.com` for private questions. Google Analytics runs only on the home page; support and privacy pages do not initialize analytics or set analytics cookies. The Pages workflow deploys only when manually run. Publication is a separate step.

Review the release checklist for outstanding publication checks. See [SECURITY.md](SECURITY.md) for private vulnerability reporting.

1. Set the paid Apple Developer team ID in `Config/Team.xcconfig`.
2. `xcodegen generate`
3. Choose the app’s scheme and a physical-device destination. In Xcode: Product → Archive → Distribute App → App Store Connect.

## Support development

If these apps are useful to you, you can [leave a one-time tip on Ko-fi](https://ko-fi.com/droessmj). No subscription required.
Contributions are optional and do not unlock app features, grant commercial-use rights, or guarantee features, release dates, or support response times.

## License

Copyright (c) 2026 Michael Droessler.

Blotter is licensed under the [PolyForm Noncommercial License 1.0.0](LICENSE). You may use, modify, and share it for
personal and other noncommercial purposes. Charities, schools, public research organizations, and government
institutions may also use it.

**Commercial use requires a separate license.** That includes selling Blotter or derivatives, offering it as part of
a paid product or service, or using it in a business. To ask about commercial licensing, open an issue in this
repository or contact the copyright holder.
