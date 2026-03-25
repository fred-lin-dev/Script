#!/bin/bash

# Historique de presse-papiers avec fzf
# Nécessite : xclip, fzf
# Usage: ./clip_history.sh
# Astuce: lier ce script à un raccourci i3 pour un accès rapide

HISTORY_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/clip_history.txt"
MAX_ENTRIES=200

mkdir -p "$(dirname "$HISTORY_FILE")"
touch "$HISTORY_FILE"

# --- Mode démon : surveille le presse-papiers et sauvegarde les nouveaux contenus ---
if [ "${1:-}" = "--daemon" ]; then
    LAST=""
    while true; do
        CURRENT=$(xclip -o -selection clipboard 2>/dev/null || true)
        if [ -n "$CURRENT" ] && [ "$CURRENT" != "$LAST" ]; then
            LAST="$CURRENT"
            # Échappe les newlines pour stocker sur une seule ligne, préfixe avec timestamp
            ENTRY=$(echo "$CURRENT" | head -c 500 | tr '\n' '↵')
            # Evite les doublons consécutifs et les entrées déjà présentes
            if ! grep -qxF "$ENTRY" "$HISTORY_FILE" 2>/dev/null; then
                echo "$ENTRY" >> "$HISTORY_FILE"
                # Garde seulement les MAX_ENTRIES dernières entrées
                tail -n "$MAX_ENTRIES" "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" && mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"
            fi
        fi
        sleep 1
    done
fi

# --- Mode interactif : sélection via fzf puis copie dans le presse-papiers ---
if ! command -v fzf &>/dev/null; then
    echo "Erreur : fzf n'est pas installé." >&2
    exit 1
fi

if [ ! -s "$HISTORY_FILE" ]; then
    echo "Historique vide." >&2
    exit 0
fi

SELECTED=$(tac "$HISTORY_FILE" | fzf \
    --prompt="Presse-papiers > " \
    --height=40% \
    --layout=reverse \
    --no-sort \
    --preview='echo {} | tr "↵" "\n"' \
    --preview-window=down:3:wrap)

if [ -n "$SELECTED" ]; then
    # Restaure les newlines
    echo "$SELECTED" | tr '↵' '\n' | xclip -selection clipboard
    echo "Copié dans le presse-papiers."
fi
