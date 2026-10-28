# Sift

On-device SMS filter for iPhone. Texts from unknown senders that contain one of your keywords go silently to Junk;
the app keeps a 30-day activity log (sender, time, verdict, reason) and never stores message text.

## Build

Requires Xcode 26+, [XcodeGen](https://github.com/yonaskolb/XcodeGen), and an iPhone on iOS 26+.

1. Set your Apple team ID in `Config/Team.xcconfig`.
2. `xcodegen generate`
3. Open `Sift.xcodeproj`, select your iPhone, and run.
4. On the iPhone: Settings → Apps → Messages → Text Message Filter → Sift.

## Release

1. Set the paid Apple Developer team ID in `Config/Team.xcconfig`.
2. `xcodegen generate`
3. In Xcode: Product → Archive → Distribute App → App Store Connect.

## License

Copyright (c) 2026 Michael Droessler.

Sift is licensed under the [PolyForm Noncommercial License 1.0.0](LICENSE). You may use, modify, and share it for
personal and other noncommercial purposes. Charities, schools, public research organizations, and government
institutions may also use it.

**Commercial use requires a separate license.** That includes selling Sift or derivatives, offering it as part of
a paid product or service, or using it in a business. To ask about commercial licensing, open an issue in this
repository or contact the copyright holder.
