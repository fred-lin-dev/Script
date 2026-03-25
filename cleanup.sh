#!/bin/bash

# Nettoyer les fichiers temporaires, cache et corbeille pour libérer de l'espace
# Usage: ./cleanup.sh [--dry-run]
# Options:
#   --dry-run   afficher ce qui serait supprimé sans rien supprimer
# Dépendances: pacman (Arch), trash-cli (optionnel)

DRY=false
[ "$1" = "--dry-run" ] && DRY=true

$DRY && echo "[Mode dry-run — aucune suppression]" && echo ""

freed=0

clean_section() {
    local label="$1" path="$2" cmd="$3"
    if [ -e "$path" ]; then
        size=$(du -sh "$path" 2>/dev/null | cut -f1)
        if $DRY; then
            echo "  [DRY] $label : $path ($size)"
        else
            eval "$cmd" 2>/dev/null && echo "  OK  $label ($size)"
        fi
    fi
}

echo "=== Nettoyage système ==="

# Cache pacman (garder les 2 dernières versions)
if command -v paccache &>/dev/null; then
    size=$(du -sh /var/cache/pacman/pkg 2>/dev/null | cut -f1)
    if $DRY; then
        echo "  [DRY] Cache pacman (garder 2 versions) : $size"
    else
        sudo paccache -rk2 && echo "  OK  Cache pacman ($size)"
    fi
elif ! $DRY; then
    echo "  INFO: paccache non disponible (sudo pacman -S pacman-contrib)"
fi

# Paquets orphelins
if command -v pacman &>/dev/null; then
    orphans=$(pacman -Qtdq 2>/dev/null)
    if [ -n "$orphans" ]; then
        count=$(echo "$orphans" | wc -l)
        if $DRY; then
            echo "  [DRY] Paquets orphelins ($count) :"
            echo "$orphans" | sed 's/^/    /'
        else
            echo "$orphans" | sudo pacman -Rns - && echo "  OK  Paquets orphelins supprimés ($count)"
        fi
    else
        echo "  OK  Aucun paquet orphelin"
    fi
fi

echo ""
echo "=== Nettoyage utilisateur ==="

# Cache utilisateur
clean_section "Cache ~/.cache" "$HOME/.cache" "rm -rf '$HOME/.cache'/*"

# Corbeille
if command -v trash-empty &>/dev/null; then
    size=$(du -sh "$HOME/.local/share/Trash" 2>/dev/null | cut -f1)
    if $DRY; then
        echo "  [DRY] Corbeille : $size"
    else
        trash-empty && echo "  OK  Corbeille vidée ($size)"
    fi else
    clean_section "Corbeille" "$HOME/.local/share/Trash" "rm -rf '$HOME/.local/share/Trash'/*"
fi

# Fichiers temporaires
clean_section "Fichiers /tmp" "/tmp" "sudo rm -rf /tmp/* 2>/dev/null; true"

# Logs journalctl (garder 7 jours)
if command -v journalctl &>/dev/null; then
    size=$(journalctl --disk-usage 2>/dev/null | grep -o '[0-9.]*[MGK]' | tail -1)
    if $DRY; then
        echo "  [DRY] Logs journal systemd : ${size:-?}"
    else
        sudo journalctl --vacuum-time=7d &>/dev/null && echo "  OK  Logs journal (> 7 jours supprimés)"
    fi
fi

echo ""
echo "Nettoyage terminé."
