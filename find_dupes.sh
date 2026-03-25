#!/bin/bash

# Trouve les fichiers en double par hash MD5 dans un dossier
# Usage: ./find_dupes.sh [dossier]

TARGET="${1:-.}"

if [ ! -d "$TARGET" ]; then
    echo "Erreur : dossier introuvable : $TARGET" >&2
    exit 1
fi

echo "Analyse de : $TARGET"
echo ""

find "$TARGET" -type f -exec md5sum {} + \
    | sort \
    | awk '
        {
            hash = $1
            # reconstruire le chemin (peut contenir des espaces)
            $1 = ""
            sub(/^ /, "")
            path = $0
            if (hash == prev_hash) {
                if (!printed) {
                    print "--- " prev_path
                    printed = 1
                }
                print "    " path
            } else {
                printed = 0
            }
            prev_hash = hash
            prev_path = path
        }
    '
