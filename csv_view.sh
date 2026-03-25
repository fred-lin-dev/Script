#!/bin/bash

# Afficher un fichier CSV proprement aligné dans le terminal
# Usage: ./csv_view.sh <fichier.csv> [séparateur] [lignes_max]
# Exemples:
#   ./csv_view.sh data.csv
#   ./csv_view.sh data.csv ";"        # séparateur point-virgule
#   ./csv_view.sh data.csv "," 50     # afficher 50 lignes max
# Dépendances: column (util-linux), less

FILE="$1"
SEP="${2:-,}"
MAX_LINES="${3:-0}"

if [ -z "$FILE" ]; then
    echo "Usage: $0 <fichier.csv> [séparateur] [lignes_max]"
    exit 1
fi

if [ ! -f "$FILE" ]; then
    echo "Fichier introuvable : $FILE"
    exit 1
fi

TOTAL=$(wc -l < "$FILE")
echo "Fichier : $FILE  |  $TOTAL lignes  |  séparateur : '$SEP'"
echo ""

if [ "$MAX_LINES" -gt 0 ] 2>/dev/null; then
    head -n "$MAX_LINES" "$FILE" | column -t -s "$SEP" | less -S
else
    column -t -s "$SEP" "$FILE" | less -S
fi
