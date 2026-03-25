#!/bin/bash

# Renommage en lot de fichiers avec preview et confirmation
# Usage: ./batch_rename.sh [dossier] [pattern] [remplacement]
# Exemples:
#   ./batch_rename.sh . " " "_"           # espaces → underscores
#   ./batch_rename.sh ~/Photos "IMG_" ""  # supprimer préfixe IMG_
#   ./batch_rename.sh . "(?i)\.JPEG$" ".jpg"  # extensions en minuscule (regex)
# Dépendances: fzf (optionnel, pour sélection interactive)

INPUT_DIR="${1:-.}"
PATTERN="$2"
REPLACEMENT="$3"

usage() {
    echo "Usage: $0 [dossier] [pattern] [remplacement]"
    echo ""
    echo "Modes:"
    echo "  Avec pattern/remplacement : renommage par substitution"
    echo "  Sans arguments            : mode interactif (choisir parmi des presets)"
    echo ""
    echo "Exemples:"
    echo "  $0 . ' ' '_'              # espaces → underscores"
    echo "  $0 . 'IMG_' ''            # supprimer préfixe"
    echo "  $0 . '(.*)' '\L\1'        # tout en minuscule"
}

apply_rename() {
    local dir="$1" pat="$2" rep="$3"
    local files=()
    local renames=()

    mapfile -t files < <(find "$dir" -maxdepth 1 -type f | sort)
    [ ${#files[@]} -eq 0 ] && { echo "Aucun fichier trouvé dans $dir"; exit 1; }

    echo "Preview des renommages :"
    echo "─────────────────────────────────────────────────"
    local count=0
    for f in "${files[@]}"; do
        base=$(basename "$f")
        newbase=$(echo "$base" | sed "s/$pat/$rep/g")
        if [ "$base" != "$newbase" ]; then
            printf "  %-35s → %s\n" "$base" "$newbase"
            renames+=("$f|$newbase")
            ((count++))
        fi
    done

    [ $count -eq 0 ] && { echo "Aucun fichier ne correspond au pattern '$pat'"; exit 0; }
    echo "─────────────────────────────────────────────────"
    echo "$count fichier(s) à renommer."
    echo ""
    read -rp "Confirmer ? [o/N] " confirm
    [[ "$confirm" =~ ^[oOyY]$ ]] || { echo "Annulé."; exit 0; }

    for entry in "${renames[@]}"; do
        src="${entry%%|*}"
        newname="${entry##*|}"
        dir_part=$(dirname "$src")
        mv -- "$src" "$dir_part/$newname" && echo "  OK: $newname"
    done
    echo "Terminé."
}

# Mode interactif si pas de pattern fourni
if [ -z "$PATTERN" ]; then
    echo "Mode interactif — choisir un preset :"
    echo "  1) Espaces → underscores"
    echo "  2) Tout en minuscule"
    echo "  3) Supprimer caractères spéciaux (!@#\$%^&*)"
    echo "  4) Supprimer un préfixe personnalisé"
    echo "  5) Remplacer un texte personnalisé"
    echo ""
    read -rp "Choix [1-5] : " choice
    case "$choice" in
        1) PATTERN=" "; REPLACEMENT="_" ;;
        2) PATTERN='.*'; REPLACEMENT='\L&'
           # cas spécial : minuscule via rename si dispo
           command -v rename &>/dev/null \
               && { find "$INPUT_DIR" -maxdepth 1 -type f -exec rename 's/(.+)/lc($1)/e' {} + && echo "Renommage en minuscule terminé."; exit 0; } \
               || { echo "Erreur: 'rename' (perl) requis pour cette option"; exit 1; } ;;
        3) PATTERN='[!@#$%^&*()+]'; REPLACEMENT="" ;;
        4) read -rp "Préfixe à supprimer : " PATTERN; REPLACEMENT="" ;;
        5) read -rp "Texte à remplacer : " PATTERN; read -rp "Remplacer par : " REPLACEMENT ;;
        *) usage; exit 1 ;;
    esac
fi

apply_rename "$INPUT_DIR" "$PATTERN" "$REPLACEMENT"
