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

# gpg en mode --batch ne peut pas réclamer de phrase de passe : il faut la lui
# fournir. On la lit ici et on la passe par un descripteur avec
# --pinentry-mode loopback, ce qui évite de dépendre d'un pinentry graphique.
read_passphrase() {
    local prompt="$1" pass
    read -rsp "$prompt" pass
    echo >&2
    printf '%s' "$pass"
}

gpg_run() {
    # $1 = phrase de passe, reste = arguments gpg
    local pass="$1"; shift
    printf '%s' "$pass" | gpg \
        --batch \
        --pinentry-mode loopback \
        --passphrase-fd 0 \
        "$@"
}

case "$MODE" in
    enc|encrypt|e)
        OUTPUT="${FILE}.gpg"

        if [ -e "$OUTPUT" ]; then
            read -rp "'$OUTPUT' existe déjà. Écraser ? [o/N] " confirm
            [[ "$confirm" =~ ^[oOyY]$ ]] || { echo "Annulé."; exit 0; }
        fi

        PASS=$(read_passphrase "Phrase de passe : ")
        PASS2=$(read_passphrase "Confirmer       : ")

        if [ "$PASS" != "$PASS2" ]; then
            echo "Les phrases de passe ne correspondent pas. Annulé."
            exit 1
        fi
        if [ -z "$PASS" ]; then
            echo "Phrase de passe vide. Annulé."
            exit 1
        fi

        if ! gpg_run "$PASS" --symmetric --cipher-algo AES256 --yes -o "$OUTPUT" "$FILE"; then
            echo "Erreur lors du chiffrement."
            rm -f "$OUTPUT"
            exit 1
        fi
        echo "Chiffré : $OUTPUT"

        if $DELETE; then
            # On ne supprime l'original qu'après avoir vérifié que l'archive
            # se déchiffre réellement : sinon une erreur ici détruirait la
            # seule copie des données.
            if gpg_run "$PASS" --decrypt -o /dev/null "$OUTPUT" 2>/dev/null; then
                rm -f "$FILE"
                echo "Original supprimé : $FILE (déchiffrement vérifié)"
            else
                echo "Vérification du déchiffrement échouée — original CONSERVÉ : $FILE" >&2
                exit 1
            fi
        fi
        ;;

    dec|decrypt|d)
        # Deviner le nom de sortie en retirant l'extension .gpg
        OUTPUT="${FILE%.gpg}"
        if [ "$OUTPUT" = "$FILE" ]; then
            OUTPUT="${FILE}.decrypted"
        fi

        if [ -e "$OUTPUT" ]; then
            read -rp "'$OUTPUT' existe déjà. Écraser ? [o/N] " confirm
            [[ "$confirm" =~ ^[oOyY]$ ]] || { echo "Annulé."; exit 0; }
        fi

        PASS=$(read_passphrase "Phrase de passe : ")

        if ! gpg_run "$PASS" --decrypt --yes -o "$OUTPUT" "$FILE"; then
            echo "Erreur lors du déchiffrement (mauvais mot de passe ?)."
            rm -f "$OUTPUT"
            exit 1
        fi
        echo "Déchiffré : $OUTPUT"
        ;;

    *)
        echo "Mode inconnu : $MODE"
        usage
        exit 1
        ;;
esac
