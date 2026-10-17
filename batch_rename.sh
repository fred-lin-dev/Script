#!/bin/bash

# Renommage en lot de fichiers avec preview et confirmation
# Usage: ./batch_rename.sh [dossier] [pattern] [remplacement]
# Le pattern est une expression régulière POSIX de base (celle de sed), pas du PCRE.
# Exemples:
#   ./batch_rename.sh . " " "_"              # espaces → underscores
#   ./batch_rename.sh ~/Photos "IMG_" ""     # supprimer préfixe IMG_
#   ./batch_rename.sh . "\.JPEG$" ".jpg"     # changer une extension
# Dépendances: aucune (sed et bash suffisent)

INPUT_DIR="${1:-.}"
PATTERN="$2"
REPLACEMENT="$3"
TRANSFORM=""   # vide = substitution sed ; "lower"/"upper" = casse

usage() {
    echo "Usage: $0 [dossier] [pattern] [remplacement]"
    echo ""
    echo "Modes:"
    echo "  Avec pattern/remplacement : renommage par substitution (regex sed)"
    echo "  Sans arguments            : mode interactif (choisir parmi des presets)"
    echo ""
    echo "Exemples:"
    echo "  $0 . ' ' '_'              # espaces → underscores"
    echo "  $0 . 'IMG_' ''            # supprimer préfixe"
    echo "  $0 . '\.JPEG\$' '.jpg'     # changer une extension"
}

apply_rename() {
    local dir="$1" pat="$2" rep="$3"
    local files=()
    local srcs=() news=()

    mapfile -t files < <(find "$dir" -maxdepth 1 -type f | sort)
    [ ${#files[@]} -eq 0 ] && { echo "Aucun fichier trouvé dans $dir"; exit 1; }

    echo "Preview des renommages :"
    echo "─────────────────────────────────────────────────"
    for f in "${files[@]}"; do
        base=$(basename "$f")
        case "$TRANSFORM" in
            lower) newbase="${base,,}" ;;
            upper) newbase="${base^^}" ;;
            # Délimiteur \001 au lieu de / : un motif contenant un slash
            # (chemin, extension) ne casse plus la commande sed.
            *)     newbase=$(printf '%s' "$base" | sed "s"$'\001'"$pat"$'\001'"$rep"$'\001'"g") ;;
        esac

        if [ "$base" != "$newbase" ]; then
            printf "  %-35s → %s\n" "$base" "$newbase"
            srcs+=("$f")
            news+=("$newbase")
        fi
    done

    local count=${#srcs[@]}
    if [ "$count" -eq 0 ]; then
        echo "Aucun fichier ne correspond."
        exit 0
    fi
    echo "─────────────────────────────────────────────────"
    echo "$count fichier(s) à renommer."
    echo ""
    read -rp "Confirmer ? [o/N] " confirm
    [[ "$confirm" =~ ^[oOyY]$ ]] || { echo "Annulé."; exit 0; }

    local i dir_part dest ok=0 skip=0
    for ((i = 0; i < count; i++)); do
        dir_part=$(dirname "${srcs[i]}")
        dest="$dir_part/${news[i]}"
        # Ne jamais écraser un fichier existant en silence
        if [ -e "$dest" ]; then
            echo "  IGNORÉ (existe déjà): ${news[i]}"
            ((skip++))
            continue
        fi
        if mv -- "${srcs[i]}" "$dest"; then
            echo "  OK: ${news[i]}"
            ((ok++))
        fi
    done
    echo "Terminé : $ok renommé(s), $skip ignoré(s)."
}

# Mode interactif si pas de pattern fourni
if [ -z "$PATTERN" ] && [ -z "$TRANSFORM" ]; then
    echo "Mode interactif — choisir un preset :"
    echo "  1) Espaces → underscores"
    echo "  2) Tout en minuscule"
    echo "  3) Supprimer caractères spéciaux (!@#\$%^&*)"
    echo "  4) Supprimer un préfixe personnalisé"
    echo "  5) Remplacer un texte personnalisé"
    echo "  6) Tout en MAJUSCULE"
    echo ""
    read -rp "Choix [1-6] : " choice
    case "$choice" in
        1) PATTERN=" "; REPLACEMENT="_" ;;
        # La casse est gérée en bash (${var,,}) : l'ancien appel à
        # « rename » supposait la version Perl, absente sur Arch où
        # /usr/bin/rename vient d'util-linux et a une syntaxe différente.
        2) TRANSFORM="lower" ;;
        6) TRANSFORM="upper" ;;
        3) PATTERN='[!@#$%^&*()+]'; REPLACEMENT="" ;;
        4) read -rp "Préfixe à supprimer : " PATTERN; REPLACEMENT="" ;;
        5) read -rp "Texte à remplacer : " PATTERN; read -rp "Remplacer par : " REPLACEMENT ;;
        *) usage; exit 1 ;;
    esac
fi

apply_rename "$INPUT_DIR" "$PATTERN" "$REPLACEMENT"
