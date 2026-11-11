#!/bin/bash
# Argument 1: current cursor directory or file
# Argument 2: bookmark tag


PATH_TO_ADD="$1"
TAG_NAME="$2"


# Directory and file bookmarks update unified plus matching type-specific history.
SELF=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SELF")
frecency_bin="$SCRIPT_DIR/frecency"

if [ -d "$PATH_TO_ADD" ]; then
    $frecency_bin file add --route unified,dir "$PATH_TO_ADD" "$TAG_NAME" >/dev/null 2>&1
    # Append a trailing slash for directories in vifm; otherwise jumping opens the
    # parent directory and merely positions the cursor on this directory.
    [[ "$PATH_TO_ADD" != */ ]] && PATH_TO_ADD="$PATH_TO_ADD/"
else
    $frecency_bin file add --route unified,file "$PATH_TO_ADD" "$TAG_NAME" >/dev/null 2>&1
fi


vifm --remote -c "bmark! $PATH_TO_ADD $TAG_NAME"
