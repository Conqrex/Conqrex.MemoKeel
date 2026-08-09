#!/usr/bin/env bash
# Install or upgrade the Conqrex Quick Notes plasmoid (per-user, no sudo).
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
PKG="$DIR/package"
ID="com.conqrex.quicknotes"

# make sure the data broker is executable inside the package before packaging
chmod +x "$PKG/contents/code/store.sh" 2>/dev/null || true

if kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -qx "$ID"; then
    echo "Upgrading $ID ..."
    kpackagetool6 -t Plasma/Applet -u "$PKG"
else
    echo "Installing $ID ..."
    kpackagetool6 -t Plasma/Applet -i "$PKG"
fi

echo
echo "Installed to ~/.local/share/plasma/plasmoids/$ID/"
echo "Add it: right-click your desktop or panel -> Add Widgets -> search 'Conqrex Quick Notes'."
echo "If it is already placed, reload the shell to pick up changes:"
echo "    kquitapp6 plasmashell && kstart plasmashell"
