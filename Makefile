SOURCES   := $(wildcard Sources/*.swift)
BINARY    := Trampoline.app/Contents/MacOS/Trampoline
FRAMEWORKS := -framework AppKit -framework CoreServices -framework UniformTypeIdentifiers
SWIFTFLAGS := -O -warnings-as-errors

LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

.PHONY: all clean install uninstall

all: $(BINARY)

$(BINARY): $(SOURCES)
	swiftc $(SWIFTFLAGS) $(FRAMEWORKS) -o $@ $^
	cp -f trampoline_app_icon.svg Trampoline.app/Contents/Resources/

clean:
	rm -f $(BINARY)

install: all
	@echo "Installing Trampoline.app..."
	rm -rf /Applications/Trampoline.app
	cp -R Trampoline.app /Applications/
	codesign --force --deep --sign - /Applications/Trampoline.app
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
