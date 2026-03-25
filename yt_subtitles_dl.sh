#!/bin/bash

# Téléchargement des sous-titres/transcriptions YouTube
# Usage: ./yt_subtitles_dl.sh <URL> [langue] [dossier_sortie]
# Exemple: ./yt_subtitles_dl.sh https://youtu.be/xxx fr ~/Subtitles
# Langues: fr, en, es, de, ... (auto = générés automatiquement)

URL="$1"
LANG="${2:-fr}"
OUTPUT_DIR="${3:-.}"

if [ -z "$URL" ]; then
    echo "Usage: $0 <URL_YouTube> [langue] [dossier_sortie]"
    echo "  langue par défaut : fr"
    echo "  Exemple: $0 https://youtu.be/xxx en ~/Subtitles"
    exit 1
fi

command -v yt-dlp &>/dev/null || { echo "Erreur: yt-dlp non installé"; exit 1; }

mkdir -p "$OUTPUT_DIR"

echo "Tentative de téléchargement des sous-titres manuels ($LANG)..."
yt-dlp \
    --skip-download \
    --write-subs \
    --sub-lang "$LANG" \
    --convert-subs srt \
    -o "$OUTPUT_DIR/%(title)s.%(ext)s" \
    "$URL" 2>/dev/null

# Si pas de sous-titres manuels, essayer les auto-générés
if [ $? -ne 0 ] || ! ls "$OUTPUT_DIR"/*.srt &>/dev/null 2>&1; then
    echo "Pas de sous-titres manuels, tentative avec les sous-titres auto-générés..."
    yt-dlp \
        --skip-download \
        --write-auto-subs \
        --sub-lang "$LANG" \
        --convert-subs srt \
        -o "$OUTPUT_DIR/%(title)s.%(ext)s" \
        "$URL"
fi

echo ""
echo "Fichiers téléchargés dans : $OUTPUT_DIR"
ls -lh "$OUTPUT_DIR"/*.srt 2>/dev/null || echo "Aucun sous-titre trouvé pour la langue '$LANG'."
