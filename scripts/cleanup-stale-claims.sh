#!/bin/bash
# cleanup-stale-claims.sh
# One-time cleanup: removes stale dev.devfiletypes.* entries from
# the LaunchServices secure plist that were written by a previous
# "trampoline claim --all" run. These custom UTI extensions are now
# handled silently via Info.plist registration and don't need
# explicit LS API claims.
#
# Usage: bash scripts/cleanup-stale-claims.sh

PLIST="$HOME/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist"
PLISTBUDDY="/usr/libexec/PlistBuddy"
BUNDLE_ID="com.maelos.trampoline"
UTI_PREFIX="dev.devfiletypes."
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

# Check plist exists
if [[ ! -f "$PLIST" ]]; then
    echo "Plist not found: $PLIST"
    echo "Nothing to clean up."
    exit 0
fi

# Back up plist
BACKUP="$HOME/.trampoline-ls-backup.plist"
cp "$PLIST" "$BACKUP"
echo "Backed up to $BACKUP"

# Count total entries
TOTAL=$($PLISTBUDDY -c "Print :LSHandlers" "$PLIST" 2>/dev/null | grep -c "Dict {")
echo "Found $TOTAL total LSHandlers entries"

# Walk entries in REVERSE order (highest index first to avoid index shifting)
removed=0
for (( i = TOTAL - 1; i >= 0; i-- )); do
    uti=$($PLISTBUDDY -c "Print :LSHandlers:$i:LSHandlerContentType" "$PLIST" 2>/dev/null)
    handler=$($PLISTBUDDY -c "Print :LSHandlers:$i:LSHandlerRoleAll" "$PLIST" 2>/dev/null)

    if [[ "$uti" == dev.devfiletypes.* ]] && [[ "$handler" == "$BUNDLE_ID" ]]; then
        $PLISTBUDDY -c "Delete :LSHandlers:$i" "$PLIST"
        ((removed++))
        echo "  Removed: $uti"
    fi
done

# Refresh LaunchServices (re-register Trampoline so plist handlers take effect)
$LSREGISTER -f /Applications/Trampoline.app 2>/dev/null || true

echo ""
echo "Removed $removed stale entries ($((TOTAL - removed)) remaining)"
echo "LaunchServices cache refreshed."
echo ""
echo "Verify with: trampoline status"
echo "The 60 custom UTI extensions should still show as REGISTERED."
