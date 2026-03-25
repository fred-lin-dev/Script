#!/bin/bash

# Téléchargement d'une playlist YouTube avec numérotation
# Usage: ./yt_playlist_dl.sh <URL_playlist> [dossier_sortie]

set -euo pipefail

if [ -z "${1:-}" ]; then
    echo "Usage: ./yt_playlist_dl.sh <URL_playlist> [dossier_sortie]"
    exit 1
fi

URL="$1"
OUTPUT_DIR="${2:-Playlist_$(date +%Y%m%d_%H%M%S)}"

mkdir -p "$OUTPUT_DIR"

echo "Playlist : $URL"
echo "Dossier  : $OUTPUT_DIR"
echo ""

yt-dlp \
    --ignore-errors \
    --continue \
    --no-overwrites \
    --write-info-json \
    --output "$OUTPUT_DIR/%(playlist_index)s - %(title)s.%(ext)s" \
    --merge-output-format mkv \
    "$URL"

echo ""
echo "Terminé !"
COUNT=$(find "$OUTPUT_DIR" -type f -not -name "*.json" | wc -l)
echo "$COUNT fichier(s) téléchargé(s) dans $OUTPUT_DIR/"
