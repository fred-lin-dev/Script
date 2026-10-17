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
    current=$(realpath "$START_DIR" 2>/dev/null || echo "$START_DIR")
    while true; do
        # du sort "taille<TAB>chemin". On conserve la tabulation comme
        # séparateur pour que les dossiers contenant des espaces restent
        # intacts (un awk sur $2 les tronquait au premier espace).
        listing=$(du -h --max-depth=1 "$current" 2>/dev/null | sort -rh \
            | awk -F'\t' 'NR>1 { printf "%s\t%s\n", $1, $2 }')

        if [ -z "$listing" ]; then
            echo "Aucun sous-dossier lisible dans : $current"
            break
        fi

        total=$(du -sh "$current" 2>/dev/null | cut -f1)
        selection=$(printf '%s\n' "$listing" | fzf \
            --header="$total total  —  $current  (Entrée=entrer, Backspace=remonter, Échap=quitter)" \
            --expect=esc \
            --bind="bspace:abort" \
            --prompt="Dossier > " \
            --no-sort)
        code=$?

        # 2 = fzf n'a pas pu démarrer (option invalide, ou pas de terminal
        # interactif). On s'arrête net plutôt que de remonter en silence
        # jusqu'à la racine en répétant l'erreur à chaque niveau.
        if [ $code -eq 2 ]; then
            echo "fzf n'a pas pu démarrer (terminal non interactif ?)." >&2
            exit 1
        fi

        # Backspace ou Ctrl-C : remonter d'un niveau
        if [ $code -ne 0 ]; then
            parent=$(dirname "$current")
            [ "$parent" = "$current" ] && break
            current="$parent"
            continue
        fi

        # Avec --expect, la 1re ligne est la touche pressée (vide si Entrée)
        [ "$(printf '%s\n' "$selection" | sed -n 1p)" = "esc" ] && break

        selected_dir=$(printf '%s\n' "$selection" | sed -n 2p | cut -f2-)
        [ -z "$selected_dir" ] && break
        [ -d "$selected_dir" ] && current="$selected_dir"
    done
else
    # Mode simple sans fzf
    scan "$START_DIR" "$DEPTH"
fi
