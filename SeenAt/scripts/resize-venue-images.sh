#!/bin/bash
# Resize venue images to 1600px max dimension at ~85% quality.
# Run this after adding new images to VenueImages/ to keep bundle size manageable.

VENUE_DIR="$(cd "$(dirname "$0")/../SeenAt/Resources/VenueImages" && pwd)"

if [ ! -d "$VENUE_DIR" ]; then
    echo "Error: VenueImages directory not found at $VENUE_DIR"
    exit 1
fi

echo "Processing images in $VENUE_DIR ..."
echo ""

find "$VENUE_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | while read -r img; do
    size=$(stat -f%z "$img" 2>/dev/null)
    echo "  $(basename "$img") ($(echo "scale=1; $size/1048576" | bc) MB) …"

    sips --resampleWidth 1600 "$img" --out "$img" > /dev/null 2>&1
    sips --setProperty format jpeg --setProperty formatOptions 85 "$img" --out "$img" > /dev/null 2>&1

    new_size=$(stat -f%z "$img" 2>/dev/null)
    echo "    → $(echo "scale=1; $new_size/1048576" | bc) MB"
done

echo ""
echo "Done."
