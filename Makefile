SOURCES   := $(wildcard Sources/*.swift)
BINARY    := Trampoline.app/Contents/MacOS/Trampoline
FRAMEWORKS := -framework AppKit -framework CoreServices -framework UniformTypeIdentifiers
SWIFTFLAGS := -O -warnings-as-errors

LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

VERSION := $(shell grep 'static let version' Sources/ExtensionRegistry.swift | sed 's/.*"\(.*\)"/\1/')
DMG     := Trampoline-$(VERSION).dmg

# Code signing — override via environment or command line:
#   make sign SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
#   make notarize NOTARY_PROFILE="your-profile"
# Defaults to ad-hoc signing (no notarization possible).
SIGN_IDENTITY  ?= -
ENTITLEMENTS   := Trampoline.entitlements
NOTARY_PROFILE ?= trampoline

.PHONY: all clean install uninstall dmg sign notarize

all: $(BINARY)

$(BINARY): $(SOURCES)
	swiftc $(SWIFTFLAGS) $(FRAMEWORKS) -o $@ $^
	cp -f trampoline_app_icon.svg Trampoline.app/Contents/Resources/

clean:
	rm -f $(BINARY)
	rm -f Trampoline-*.dmg
	rm -rf dmg-staging

sign: all
	@echo "Signing with: $(SIGN_IDENTITY)"
ifeq ($(SIGN_IDENTITY),-)
	codesign --force --deep --sign - Trampoline.app
else
	codesign --force --deep --sign "$(SIGN_IDENTITY)" \
		--entitlements "$(ENTITLEMENTS)" \
		--options runtime \
		Trampoline.app
endif
	@echo "Verifying signature..."
	codesign --verify --deep --strict Trampoline.app
	@echo "Signature valid."

install: all
	@echo "Installing Trampoline.app..."
	rm -rf /Applications/Trampoline.app
	cp -R Trampoline.app /Applications/
ifeq ($(SIGN_IDENTITY),-)
	codesign --force --deep --sign - /Applications/Trampoline.app
else
	codesign --force --deep --sign "$(SIGN_IDENTITY)" \
		--entitlements "$(ENTITLEMENTS)" \
		--options runtime \
		/Applications/Trampoline.app
endif
	$(LSREGISTER) -f /Applications/Trampoline.app
	@echo "Creating CLI symlink..."
	mkdir -p /usr/local/bin
	ln -sf /Applications/Trampoline.app/Contents/MacOS/Trampoline \
		/usr/local/bin/trampoline
	@echo "Done. Run 'trampoline --help' to get started."

uninstall:
	@echo "Removing Trampoline..."
	$(LSREGISTER) -u /Applications/Trampoline.app 2>/dev/null || true
	rm -f /usr/local/bin/trampoline
	rm -rf /Applications/Trampoline.app
	@echo "Clearing preferences..."
	defaults delete com.maelos.trampoline 2>/dev/null || true
	@echo "Done."

dmg: sign
	@test -n "$(VERSION)" || { echo "Error: could not extract VERSION from ExtensionRegistry.swift"; exit 1; }
	@command -v create-dmg >/dev/null 2>&1 || \
		{ echo "Error: create-dmg not found. Install with: brew install create-dmg"; exit 1; }
	@echo "Creating $(DMG)..."
	rm -f "$(DMG)"
	rm -rf dmg-staging
	mkdir dmg-staging
	ditto Trampoline.app dmg-staging/Trampoline.app
	create-dmg \
		--volname "Trampoline" \
		--window-pos 200 120 \
		--window-size 600 400 \
		--icon-size 128 \
		--icon "Trampoline.app" 150 190 \
		--hide-extension "Trampoline.app" \
		--app-drop-link 450 190 \
		"$(DMG)" \
		dmg-staging/ \
		|| test $$? -eq 2  # exit 2 = DMG created but Finder cosmetics failed
	rm -rf dmg-staging
	@echo "Created $(DMG)"

notarize: dmg
	@test "$(SIGN_IDENTITY)" != "-" || { echo "Error: notarization requires a Developer ID. Set SIGN_IDENTITY."; exit 1; }
	@echo "Submitting $(DMG) for notarization..."
	xcrun notarytool submit "$(DMG)" \
		--keychain-profile "$(NOTARY_PROFILE)" \
		--wait
	@echo "Stapling notarization ticket..."
	xcrun stapler staple "$(DMG)"
	@echo "Notarization complete."
