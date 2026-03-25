#!/bin/bash

# Extraire n'importe quelle archive en une seule commande
# Usage: ./extract.sh <archive> [dossier_destination]
# Formats supportés: tar.gz, tar.bz2, tar.xz, tar.zst, zip, 7z, rar, gz, bz2, xz, zst
# Exemples:
#   ./extract.sh archive.tar.gz
#   ./extract.sh archive.zip ~/Documents

ARCHIVE="$1"
DEST="${2:-.}"

if [ -z "$ARCHIVE" ]; then
    echo "Usage: $0 <archive> [dossier_destination]"
    exit 1
fi

if [ ! -f "$ARCHIVE" ]; then
    echo "Fichier introuvable : $ARCHIVE"
    exit 1
fi

mkdir -p "$DEST"

case "${ARCHIVE,,}" in
    *.tar.gz|*.tgz)   tar -xzf  "$ARCHIVE" -C "$DEST" ;;
    *.tar.bz2|*.tbz2) tar -xjf  "$ARCHIVE" -C "$DEST" ;;
    *.tar.xz|*.txz)   tar -xJf  "$ARCHIVE" -C "$DEST" ;;
    *.tar.zst)         tar --zstd -xf "$ARCHIVE" -C "$DEST" ;;
    *.tar)             tar -xf   "$ARCHIVE" -C "$DEST" ;;
    *.zip)             unzip -q  "$ARCHIVE" -d "$DEST" ;;
    *.7z)              7z x      "$ARCHIVE" -o"$DEST" -y ;;
    *.rar)             unrar x   "$ARCHIVE"  "$DEST"  ;;
    *.gz)              gunzip -k "$ARCHIVE" && [ "$DEST" != "." ] && mv "${ARCHIVE%.gz}" "$DEST/" ;;
    *.bz2)             bunzip2 -k "$ARCHIVE" && [ "$DEST" != "." ] && mv "${ARCHIVE%.bz2}" "$DEST/" ;;
    *.xz)              xz -dk    "$ARCHIVE" && [ "$DEST" != "." ] && mv "${ARCHIVE%.xz}" "$DEST/" ;;
    *.zst)             zstd -dk  "$ARCHIVE" && [ "$DEST" != "." ] && mv "${ARCHIVE%.zst}" "$DEST/" ;;
    *) echo "Format non reconnu : $ARCHIVE"; exit 1 ;;
esac

echo "Extrait dans : $DEST"
