#!/bin/bash

# Téléchargement audio YouTube en mp3
# Usage: ./yt_audio_dl.sh <URL> [dossier_sortie]

set -euo pipefail

if [ -z "${1:-}" ]; then
    echo "Usage: ./yt_audio_dl.sh <URL> [dossier_sortie]"
    exit 1
fi

URL="$1"
OUTPUT_DIR="${2:-.}"

mkdir -p "$OUTPUT_DIR"

yt-dlp \
    --extract-audio \
    --audio-format mp3 \
    --audio-quality 0 \
    --embed-thumbnail \
    --add-metadata \
    --no-playlist \
    --output "$OUTPUT_DIR/%(title)s.%(ext)s" \
    "$URL"
