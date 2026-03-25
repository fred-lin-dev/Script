#!/bin/bash

# Générateur de mots de passe forts aléatoires
# Usage: ./mkpasswd.sh [longueur] [nombre] [options]
# Options:
#   -s  simple : lettres + chiffres seulement (sans caractères spéciaux)
#   -p  prononçable : mots aléatoires séparés par tiret (ex: rouge-chien-42)
# Exemples:
#   ./mkpasswd.sh              # 1 mot de passe de 20 caractères
#   ./mkpasswd.sh 32           # longueur 32
#   ./mkpasswd.sh 20 5         # 5 mots de passe de 20 caractères
#   ./mkpasswd.sh 20 1 -s      # sans caractères spéciaux
#   ./mkpasswd.sh -p           # mot de passe prononçable

LENGTH=20
COUNT=1
MODE="full"

# Parser les arguments
for arg in "$@"; do
    case "$arg" in
        -s) MODE="simple" ;;
        -p) MODE="passphrase" ;;
        [0-9]*)
            if [ "$LENGTH" -eq 20 ] && [ "$arg" -gt 0 ] 2>/dev/null; then
                LENGTH="$arg"
            elif [ "$COUNT" -eq 1 ]; then
                COUNT="$arg"
            fi
            ;;
    esac
done

# Réassigner correctement si deux nombres fournis
NUMS=()
for arg in "$@"; do
    [[ "$arg" =~ ^[0-9]+$ ]] && NUMS+=("$arg")
done
[ ${#NUMS[@]} -ge 1 ] && LENGTH="${NUMS[0]}"
[ ${#NUMS[@]} -ge 2 ] && COUNT="${NUMS[1]}"

gen_full() {
    # Lettres + chiffres + caractères spéciaux
    local chars='A-Za-z0-9!@#$%^&*()-_=+[]{}|;:,.<>?'
    tr -dc "$chars" < /dev/urandom | head -c "$LENGTH"
    echo
}

gen_simple() {
    # Lettres + chiffres uniquement
    tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$LENGTH"
    echo
}

gen_passphrase() {
    # 4 mots aléatoires depuis le dictionnaire système
    local dict=""
    for d in /usr/share/dict/french /usr/share/dict/words /usr/share/dict/french-utf8; do
        [ -f "$d" ] && dict="$d" && break
    done

    if [ -z "$dict" ]; then
        # Fallback : combinaison de syllabes aléatoires
        local syllables=(ba be bi bo bu ca ce ci co cu da de di do du fa fe fi fo fu ga ge gi go gu la le li lo lu ma me mi mo mu na ne ni no nu pa pe pi po pu ra re ri ro ru sa se si so su ta te ti to tu va ve vi vo vu)
        local word=""
        for _ in 1 2 3 4; do
            local w=""
            for _ in 1 2 3; do
                w+="${syllables[$RANDOM % ${#syllables[@]}]}"
            done
            word="${word:+$word-}$w"
        done
        echo "$word-$((RANDOM % 9000 + 1000))"
        return
    fi

    # 4 mots du dictionnaire (longueur 4-8 lettres)
    grep -E '^[a-zA-Z]{4,8}$' "$dict" | shuf -n 4 | tr '[:upper:]' '[:lower:]' | paste -sd '-'
    echo "-$((RANDOM % 9000 + 1000))"
}

# Générer
for ((i = 0; i < COUNT; i++)); do
    case "$MODE" in
        full)       gen_full ;;
        simple)     gen_simple ;;
        passphrase) gen_passphrase | tr -d '\n'; echo ;;
    esac
done | if command -v xclip &>/dev/null && [ "$COUNT" -eq 1 ]; then
    tee /dev/tty | xclip -selection clipboard
    echo "[Copié dans le presse-papiers]" >&2
elif command -v wl-copy &>/dev/null && [ "$COUNT" -eq 1 ]; then
    tee /dev/tty | wl-copy
    echo "[Copié dans le presse-papiers]" >&2
else
    cat
fi
