#!/bin/bash

# Convertit un fichier .srt en texte brut (supprime timestamps et numéros)
# Usage: ./srt_to_txt.sh <fichier.srt> [fichier_sortie.txt]
# Si pas de fichier de sortie : affiche dans le terminal + copie dans le presse-papiers
# Exemples:
#   ./srt_to_txt.sh video.srt
#   ./srt_to_txt.sh video.srt transcript.txt

INPUT="$1"
OUTPUT="$2"

if [ -z "$INPUT" ]; then
    echo "Usage: $0 <fichier.srt> [fichier_sortie.txt]"
    exit 1
fi

if [ ! -f "$INPUT" ]; then
    echo "Fichier introuvable : $INPUT"
    exit 1
fi

# Extraction : supprimer numéros de séquence, timestamps, lignes vides multiples
TEXT=$(sed \
    -e '/^[0-9]\+$/d' \
    -e '/^[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\},[0-9]\{3\} --> /d' \
    -e '/^$/d' \
    "$INPUT" \
    | sed -e 's/<[^>]*>//g' \       # supprimer balises HTML (<i>, <b>, etc.)
    | sed -e 's/^[[:space:]]*//' \  # supprimer espaces en début de ligne
    | cat -s \                       # réduire les lignes vides multiples
    | awk '
        # Fusionner les lignes consécutives qui forment une même phrase
        /^$/ { if (buf != "") { print buf; buf="" } print ""; next }
        { buf = (buf == "") ? $0 : buf " " $0 }
        END { if (buf != "") print buf }
    ')

if [ -n "$OUTPUT" ]; then
    echo "$TEXT" > "$OUTPUT"
    LINES=$(echo "$TEXT" | wc -l)
    WORDS=$(echo "$TEXT" | wc -w)
    echo "Sauvegardé : $OUTPUT ($WORDS mots, $LINES lignes)"
else
    echo "$TEXT"
    echo ""
    # Copier dans le presse-papiers si disponible
    if command -v xclip &>/dev/null; then
        echo "$TEXT" | xclip -selection clipboard
        echo "[Copié dans le presse-papiers]"
    elif command -v wl-copy &>/dev/null; then
        echo "$TEXT" | wl-copy
        echo "[Copié dans le presse-papiers]"
    fi
fi
