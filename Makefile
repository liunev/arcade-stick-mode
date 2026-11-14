APP_NAME    := Arcade Stick Mode
BUNDLE_ID   := io.github.liunev.arcade-stick-mode
BUILD_DIR   := build
APP         := $(BUILD_DIR)/$(APP_NAME).app
INSTALL_DIR ?= $(HOME)/Applications
INSTALLED   := $(INSTALL_DIR)/$(APP_NAME).app

# Release build (maintainers): universal, Developer ID signed, notarized
VERSION        := $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist)
MIN_MACOS      := 13.0
DIST_DIR       := dist
DIST_APP       := $(DIST_DIR)/$(APP_NAME).app
DIST_ZIP       := $(DIST_DIR)/Arcade-Stick-Mode-$(VERSION).zip
SIGN_ID        ?= Developer ID Application
NOTARY_PROFILE ?= arcade-stick-mode

.PHONY: build install uninstall quit clean dist-app release

# Compile the app and assemble the .app bundle in ./build
build:
	mkdir -p "$(APP)/Contents/MacOS"
	swiftc -O ArcadeStickMode.swift -o "$(APP)/Contents/MacOS/ArcadeStickMode"
	cp Info.plist "$(APP)/Contents/Info.plist"
	codesign --force --sign - "$(APP)"
	@echo "Built $(APP)"

# Quit a running copy (this also returns the stick to Switch mode)
quit:
	@if pgrep -x ArcadeStickMode >/dev/null; then \
		osascript -e 'tell application "$(APP_NAME)" to quit' >/dev/null 2>&1 || pkill -x ArcadeStickMode || true; \
		sleep 1; \
	fi

# Build, copy to ~/Applications and start it
install: build quit
	mkdir -p "$(INSTALL_DIR)"
	rm -rf "$(INSTALLED)"
	cp -R "$(APP)" "$(INSTALLED)"
	open "$(INSTALLED)"
	@echo "Installed and started $(INSTALLED)"

uninstall: quit
	rm -rf "$(INSTALLED)"
	@defaults delete $(BUNDLE_ID) >/dev/null 2>&1 || true
	@echo "Removed $(INSTALLED)"

clean:
	rm -rf "$(BUILD_DIR)" "$(DIST_DIR)"

# Universal (Apple Silicon + Intel) app signed with the hardened runtime
dist-app:
	rm -rf "$(DIST_DIR)"
	mkdir -p "$(DIST_APP)/Contents/MacOS"
	swiftc -O -target arm64-apple-macos$(MIN_MACOS) ArcadeStickMode.swift -o "$(DIST_DIR)/arm64"
	swiftc -O -target x86_64-apple-macos$(MIN_MACOS) ArcadeStickMode.swift -o "$(DIST_DIR)/x86_64"
	lipo -create "$(DIST_DIR)/arm64" "$(DIST_DIR)/x86_64" -output "$(DIST_APP)/Contents/MacOS/ArcadeStickMode"
	rm "$(DIST_DIR)/arm64" "$(DIST_DIR)/x86_64"
	cp Info.plist "$(DIST_APP)/Contents/Info.plist"
	codesign --force --options runtime --timestamp --sign "$(SIGN_ID)" "$(DIST_APP)"
	codesign --verify --strict "$(DIST_APP)"

# Needs a "Developer ID Application" certificate in the keychain and
# notarization credentials saved once with:
#   xcrun notarytool store-credentials arcade-stick-mode
release: dist-app
	ditto -c -k --keepParent "$(DIST_APP)" "$(DIST_ZIP)"
	xcrun notarytool submit "$(DIST_ZIP)" --keychain-profile "$(NOTARY_PROFILE)" --wait
	xcrun stapler staple "$(DIST_APP)"
	rm "$(DIST_ZIP)"
	ditto -c -k --keepParent "$(DIST_APP)" "$(DIST_ZIP)"
	spctl --assess --type execute --verbose "$(DIST_APP)"
	@echo "Release archive: $(DIST_ZIP)"
