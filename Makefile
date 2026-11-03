DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
export DEVELOPER_DIR

APP ?= Daymark
TEST_DESTINATION ?= platform=iOS Simulator,name=iPhone 18 Pro

.PHONY: generate build test-core test-sift test-ui archive-check

generate:
	xcodegen generate

# Simulator signing preserves the entitlements required by shared preferences and Keychain cleanup.
build: generate
	xcodebuild -project Sift.xcodeproj -scheme $(APP) -destination 'generic/platform=iOS Simulator' -derivedDataPath build/$(APP) CODE_SIGN_IDENTITY=- build

test-core:
	swift test --package-path packages/HabitKit --scratch-path build/HabitKit

test-sift:
	swift test --package-path apps/Sift --scratch-path build/SiftTests

test-ui: generate
	xcodebuild -project Sift.xcodeproj -scheme Daymark -destination '$(TEST_DESTINATION)' -derivedDataPath build/Daymark -parallel-testing-enabled NO CODE_SIGN_IDENTITY=- test

# Packaging check only. App Store uploads require a separately validated signed archive.
archive-check: generate
	xcodebuild -project Sift.xcodeproj -scheme $(APP) -configuration Release -destination 'generic/platform=iOS' -derivedDataPath build/$(APP)Release -archivePath build/archives/$(APP)-unsigned.xcarchive CODE_SIGNING_ALLOWED=NO archive
