#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/plasmoid"
ID="com.github.raindancer118.showerthoughts"

if kpackagetool6 --show "$ID" &>/dev/null 2>&1; then
    echo "Updating existing installation..."
    kpackagetool6 -t Plasma/Applet --upgrade "$DIR"
else
    echo "Installing for the first time..."
    kpackagetool6 -t Plasma/Applet --install "$DIR"
fi

echo ""
echo "Done. Right-click the desktop → Add Widgets → search 'Showerthoughts'."
echo "To reload Plasma without logging out:"
echo "  plasmashell --replace &"
