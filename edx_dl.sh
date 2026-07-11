#!/usr/bin/env bash
# Téléchargement d'un cours depuis une URL YouTube (playlist CS50, etc.)
# Usage : ./edx_dl.sh <URL_playlist_youtube> <dossier_cours> [cookies.txt]
# Exemple : ./edx_dl.sh "https://www.youtube.com/playlist?list=PLhQjrBD2T383..." CS50_Cybersecurity
# Structure créée : ~/cours_harvard/<dossier_cours>/N - Titre.mkv

set -euo pipefail

URL="${1:?Usage: $0 <URL_playlist_youtube> <dossier_cours> [cookies.txt]}"
COURSE_DIR="${2:?Usage: $0 <URL_playlist_youtube> <dossier_cours> [cookies.txt]}"
COOKIES="${3:-}"

if ! command -v yt-dlp &>/dev/null; then
  echo "[ERREUR] yt-dlp n'est pas installé." >&2
  exit 1
fi

COOKIE_ARGS=()
if [[ -n "$COOKIES" ]]; then
  if [[ ! -f "$COOKIES" ]]; then
    echo "[ERREUR] Fichier cookies introuvable : $COOKIES" >&2
    exit 1
  fi
  COOKIE_ARGS=(--cookies "$COOKIES")
fi

mkdir -p "$COURSE_DIR"

echo ""
echo "====================================================="
echo " Cours  : $URL"
echo " Sortie : $COURSE_DIR/"
echo "====================================================="
echo ""

yt-dlp \
  "${COOKIE_ARGS[@]}" \
  --ignore-errors \
  --continue \
  --no-overwrites \
  --write-subs \
  --write-auto-subs \
  --sub-langs "fr,en" \
  --convert-subs srt \
  --output "$COURSE_DIR/%(playlist_index)s - %(title)s.%(ext)s" \
  --merge-output-format mkv \
  "$URL"

echo ""
echo "====================================================="
echo " RÉSUMÉ"
echo "====================================================="
VIDEO_COUNT=$(find "$COURSE_DIR" -type f -name "*.mkv" | wc -l)
SRT_COUNT=$(find "$COURSE_DIR" -type f -name "*.srt" | wc -l)
echo " Vidéos       : $VIDEO_COUNT  →  $COURSE_DIR/"
echo " Sous-titres  : $SRT_COUNT"
echo "====================================================="
echo ""
