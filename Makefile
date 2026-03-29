SOURCES   := $(wildcard Sources/*.swift)
BINARY    := Trampoline.app/Contents/MacOS/Trampoline
FRAMEWORKS := -framework AppKit -framework CoreServices -framework UniformTypeIdentifiers
SWIFTFLAGS := -O -warnings-as-errors

LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

.PHONY: all clean install uninstall

all: $(BINARY)

$(BINARY): $(SOURCES)
	swiftc $(SWIFTFLAGS) $(FRAMEWORKS) -o $@ $^

clean:
	rm -f $(BINARY)

install: all
	cp -R Trampoline.app /Applications/
	$(LSREGISTER) -f /Applications/Trampoline.app
	ln -sf /Applications/Trampoline.app/Contents/MacOS/Trampoline /usr/local/bin/trampoline

uninstall:
	rm -f /usr/local/bin/trampoline
	rm -rf /Applications/Trampoline.app
