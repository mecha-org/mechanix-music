#!/bin/sh
APPDIR="/usr/share/mechanix/mechanix-music"
exec "$APPDIR/mechanix_music" --bundle="$APPDIR" "$@"
