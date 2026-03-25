#!/bin/bash

# Aide-mémoire de commandes shell via cheat.sh
# Usage:
#   ./cheat.sh <commande>              # aide générale
#   ./cheat.sh <commande> <cas>        # cas d'usage spécifique
#   ./cheat.sh tar extract             # exemple: extraire un tar
#   ./cheat.sh ffmpeg convert          # exemple: convertir avec ffmpeg
# Dépendances: curl

usage() {
    echo "Usage: $0 <commande> [cas_usage]"
    echo ""
    echo "Exemples:"
    echo "  $0 tar"
    echo "  $0 tar extract"
    echo "  $0 ffmpeg"
    echo "  $0 curl post"
    echo "  $0 git rebase"
    echo "  $0 rsync"
}

if [ -z "$1" ]; then usage; exit 1; fi

command -v curl &>/dev/null || { echo "Erreur: curl non installé"; exit 1; }

CMD="$1"
TOPIC="${2:-}"

if [ -n "$TOPIC" ]; then
    QUERY="$CMD/$TOPIC"
else
    QUERY="$CMD"
fi

# Désactiver les couleurs si pas dans un terminal
if [ -t 1 ]; then
    curl -s "https://cheat.sh/$QUERY" 2>/dev/null | less -R
else
    curl -s "https://cheat.sh/$QUERY?T" 2>/dev/null
fi
