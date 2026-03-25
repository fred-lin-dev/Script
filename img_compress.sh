#!/bin/bash

# Compression d'images en lot avec preview de la réduction
# Usage: ./img_compress.sh [dossier] [qualité] [format_sortie]
# Exemple: ./img_compress.sh ~/Photos 80 jpg
# Formats supportés: jpg, png, webp
# Dépendances: imagemagick (convert), optipng (optionnel pour png)

INPUT_DIR="${1:-.}"
QUALITY="${2:-85}"
FORMAT="${3:-}"  # vide = même format que l'original

command -v convert &>/dev/null || { echo "Erreur: imagemagick non installé (sudo pacman -S imagemagick)"; exit 1; }

# Collecter les images
mapfile -t IMAGES < <(find "$INPUT_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | sort)

if [ ${#IMAGES[@]} -eq 0 ]; then
    echo "Aucune image trouvée dans : $INPUT_DIR"
    exit 1
fi

echo "Images trouvées : ${#IMAGES[@]}"
echo "Qualité : $QUALITY%"
[ -n "$FORMAT" ] && echo "Format de sortie : $FORMAT"
echo ""

# Créer le dossier de sortie
OUTPUT_DIR="$INPUT_DIR/compressed"
mkdir -p "$OUTPUT_DIR"

TOTAL_BEFORE=0
TOTAL_AFTER=0

for IMG in "${IMAGES[@]}"; do
    BASENAME=$(basename "$IMG")
    NAME="${BASENAME%.*}"
    EXT="${BASENAME##*.}"
    OUT_EXT="${FORMAT:-$EXT}"
    OUT_FILE="$OUTPUT_DIR/${NAME}.${OUT_EXT,,}"

    SIZE_BEFORE=$(stat -c%s "$IMG")
    TOTAL_BEFORE=$((TOTAL_BEFORE + SIZE_BEFORE))

    convert "$IMG" -quality "$QUALITY" "$OUT_FILE" 2>/dev/null

    SIZE_AFTER=$(stat -c%s "$OUT_FILE")
    TOTAL_AFTER=$((TOTAL_AFTER + SIZE_AFTER))

    REDUCTION=$(( (SIZE_BEFORE - SIZE_AFTER) * 100 / SIZE_BEFORE ))
    printf "  %-40s %6dK → %6dK  (-%d%%)\n" \
        "$BASENAME" \
        $((SIZE_BEFORE / 1024)) \
        $((SIZE_AFTER / 1024)) \
        "$REDUCTION"
done

echo ""
TOTAL_REDUCTION=$(( (TOTAL_BEFORE - TOTAL_AFTER) * 100 / TOTAL_BEFORE ))
echo "Total : $((TOTAL_BEFORE / 1024))K → $((TOTAL_AFTER / 1024))K (-${TOTAL_REDUCTION}%)"
echo "Fichiers compressés dans : $OUTPUT_DIR"
