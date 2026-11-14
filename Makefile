APP_NAME    := Arcade Stick Mode
BUNDLE_ID   := io.github.liunev.arcade-stick-mode
BUILD_DIR   := build
APP         := $(BUILD_DIR)/$(APP_NAME).app
INSTALL_DIR ?= $(HOME)/Applications
INSTALLED   := $(INSTALL_DIR)/$(APP_NAME).app

.PHONY: build install uninstall quit clean

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
	rm -rf "$(BUILD_DIR)"
