#!/bin/bash

# Visualiser l'espace disque par dossier, navigable avec fzf
# Usage: ./disk_usage.sh [dossier] [profondeur]
# Exemples:
#   ./disk_usage.sh              # dossier courant, profondeur 1
#   ./disk_usage.sh ~ 2          # home, profondeur 2
#   ./disk_usage.sh /var 1
# Dépendances: fzf (optionnel mais recommandé)

START_DIR="${1:-$HOME}"
DEPTH="${2:-1}"

command -v du &>/dev/null || { echo "Erreur: du non disponible"; exit 1; }

scan() {
    local dir="$1" depth="$2"
    echo "Analyse de $dir (profondeur $depth)..."
    du -h --max-depth="$depth" "$dir" 2>/dev/null | sort -rh
}

if command -v fzf &>/dev/null; then
    # Mode interactif : naviguer dans les dossiers
    current="$START_DIR"
    while true; do
        selection=$(
            du -h --max-depth=1 "$current" 2>/dev/null \
            | sort -rh \
            | awk -v cur="$current" '
                NR==1 { total=$0; next }
                { printf "%-10s %s\n", $1, $2 }
            ' \
            | fzf \
                --header="$(du -sh "$current" 2>/dev/null | cut -f1) total  —  $current  (Entrée=entrer, Échap=quitter, backspace=remonter)" \
                --bind="backward-delete-char:abort" \
                --prompt="Dossier > " \
                --no-sort \
                --ansi
        )

        code=$?
        # Échap ou backspace
        [ $code -ne 0 ] && {
            parent=$(dirname "$current")
            [ "$parent" = "$current" ] && break
            current="$parent"
            continue
        }

        selected_dir=$(echo "$selection" | awk '{print $2}')
        [ -z "$selected_dir" ] && break

        if [ -d "$selected_dir" ]; then
            current="$selected_dir"
        fi
    done
else
    # Mode simple sans fzf
    scan "$START_DIR" "$DEPTH"
fi
