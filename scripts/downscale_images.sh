#!/bin/bash

TARGET_DIR="${1:-.}"
TARGET_SIZE=1000000
QUALITY=85
THREADS=4

compress_one() {
    img="$1"
    echo "Processing: $img"
    cp "$img" "$img.bak"

    width=$(identify -format "%w" "$img")
    height=$(identify -format "%h" "$img")
    current_size=$(stat -c%s "$img")

    while [ "$current_size" -gt "$TARGET_SIZE" ] && [ "$width" -gt 600 ]; do
        width=$(( width * 90 / 100 ))
        height=$(( height * 90 / 100 ))
        mogrify -resize "${width}x${height}" -strip -interlace Plane -sampling-factor 4:2:0 -quality $QUALITY "$img"
        current_size=$(stat -c%s "$img")
    done

    echo "→ Final: $(du -h "$img" | cut -f1)"
}

export -f compress_one
export TARGET_SIZE QUALITY

find "$TARGET_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) -size +2M \
  | parallel -j "$THREADS" compress_one {}
