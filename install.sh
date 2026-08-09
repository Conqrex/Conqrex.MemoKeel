#!/usr/bin/env bash
# Install or upgrade the MemoKeel plasmoid (per-user, no sudo).
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
PKG="$DIR/package"
ID="com.conqrex.memokeel"
OLD_ID="com.conqrex.quicknotes"
# same resolution store.sh uses, so the printed paths match reality
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

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
echo "Installed to $DATA_HOME/plasma/plasmoids/$ID/"
echo
echo "MemoKeel is a NEW package id (was $OLD_ID), so it does not replace an"
echo "existing Quick Notes applet in place. Add it once:"
echo "    right-click your desktop or panel -> Add Widgets -> search 'MemoKeel'."
echo
echo "Your notes migrate automatically on first run: the old folder"
echo "$DATA_HOME/conqrex/quicknotes/ is COPIED to"
echo "$DATA_HOME/conqrex/memokeel/"
echo "and left in place as a backup — nothing there is moved or deleted."
echo
echo "Once MemoKeel is on your panel and your notes are there, remove the"
echo "superseded applet yourself with:"
echo "    kpackagetool6 -t Plasma/Applet -r $OLD_ID"
echo
echo "If MemoKeel is already placed, reload the shell to pick up changes:"
echo "    kquitapp6 plasmashell && kstart plasmashell"
