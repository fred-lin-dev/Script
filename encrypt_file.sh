#!/bin/bash

# Chiffrer ou déchiffrer un fichier avec un mot de passe (GPG AES-256)
# Usage:
#   ./encrypt_file.sh enc <fichier>          # chiffrer → fichier.gpg
#   ./encrypt_file.sh dec <fichier.gpg>      # déchiffrer → fichier original
#   ./encrypt_file.sh enc <fichier> -d       # chiffrer puis supprimer l'original
# Dépendances: gpg

command -v gpg &>/dev/null || { echo "Erreur: gpg non installé (sudo pacman -S gnupg)"; exit 1; }

MODE="$1"
FILE="$2"
DELETE=false
[ "$3" = "-d" ] && DELETE=true

usage() {
    echo "Usage:"
    echo "  $0 enc <fichier>       # chiffrer"
    echo "  $0 dec <fichier.gpg>   # déchiffrer"
    echo "  $0 enc <fichier> -d    # chiffrer + supprimer l'original"
}

if [ -z "$MODE" ] || [ -z "$FILE" ]; then usage; exit 1; fi
if [ ! -f "$FILE" ]; then echo "Fichier introuvable : $FILE"; exit 1; fi

case "$MODE" in
    enc|encrypt|e)
        OUTPUT="${FILE}.gpg"
        gpg --symmetric \
            --cipher-algo AES256 \
            --batch \
            --yes \
            -o "$OUTPUT" \
            "$FILE"
        if [ $? -eq 0 ]; then
            echo "Chiffré : $OUTPUT"
            if $DELETE; then
                rm "$FILE"
                echo "Original supprimé : $FILE"
            fi
        else
            echo "Erreur lors du chiffrement."
            exit 1
        fi
        ;;

    dec|decrypt|d)
        # Deviner le nom de sortie en retirant l'extension .gpg
        OUTPUT="${FILE%.gpg}"
        if [ "$OUTPUT" = "$FILE" ]; then
            OUTPUT="${FILE}.decrypted"
        fi
        gpg --decrypt \
            --batch \
            --yes \
            -o "$OUTPUT" \
            "$FILE"
        if [ $? -eq 0 ]; then
            echo "Déchiffré : $OUTPUT"
        else
            echo "Erreur lors du déchiffrement (mauvais mot de passe ?)."
            exit 1
        fi
        ;;

    *)
        echo "Mode inconnu : $MODE"
        usage
        exit 1
        ;;
esac
