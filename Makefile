DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
export DEVELOPER_DIR

APP ?= DayInInk
TEST_DESTINATION ?= platform=iOS Simulator,name=iPhone 18 Pro

.PHONY: generate build test-core test-blotter test-ui archive-check

generate:
	xcodegen generate

# Ad-hoc simulator signing preserves the entitlements required by shared preferences.
build: generate
	xcodebuild -project Blotter.xcodeproj -scheme $(APP) -destination 'generic/platform=iOS Simulator' -derivedDataPath build/$(APP) CODE_SIGN_IDENTITY=- build

test-core:
	swift test --package-path packages/HabitKit --scratch-path build/HabitKit

test-blotter:
	swift test --package-path apps/Blotter --scratch-path build/BlotterTests

test-ui: generate
	xcodebuild -project Blotter.xcodeproj -scheme DayInInk -destination '$(TEST_DESTINATION)' -derivedDataPath build/DayInInk -parallel-testing-enabled NO CODE_SIGN_IDENTITY=- test

# Packaging check only. App Store uploads require a separately validated signed archive.
archive-check: generate
	xcodebuild -project Blotter.xcodeproj -scheme $(APP) -configuration Release -destination 'generic/platform=iOS' -derivedDataPath build/$(APP)Release -archivePath build/archives/$(APP)-unsigned.xcarchive CODE_SIGNING_ALLOWED=NO archive
