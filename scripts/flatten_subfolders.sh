#!/bin/bash
# Flatten all files from subfolders into the root folder

ROOT="${1:-.}"   # default: current folder
DEST="${2:-$ROOT}" # optional second arg for destination

find "$ROOT" -type f | while read -r file; do
    base=$(basename "$file")
    target="$DEST/$base"

    # Handle duplicate filenames
    if [ -e "$target" ]; then
        ext="${base##*.}"
        name="${base%.*}"
        target="$DEST/${name}_$(date +%s%N).$ext"
    fi

    mv "$file" "$target"
done

# Remove empty folders
find "$ROOT" -type d -empty -delete

echo "✅ All files moved to: $DEST"
