#!/bin/bash

# Sélectionner une zone d'écran, extraire le texte et le copier dans le presse-papiers
# Dépendances : scrot, tesseract, xclip
# Usage: ./screenshot_ocr.sh [langue]
# Langues tesseract : fra, eng, auto (défaut: fra+eng)

LANG="${1:-fra+eng}"
TMP=$(mktemp /tmp/ocr_XXXXXX.png)

cleanup() { rm -f "$TMP"; }
trap cleanup EXIT

scrot -s "$TMP" 2>/dev/null

if [ ! -s "$TMP" ]; then
    exit 0
fi

TEXT=$(tesseract "$TMP" stdout -l "$LANG" 2>/dev/null | sed '/^$/d')

if [ -z "$TEXT" ]; then
    notify-send "OCR" "Aucun texte détecté." -i dialog-warning
    exit 0
fi

echo "$TEXT" | xclip -selection clipboard
notify-send "OCR" "Texte copié ($(echo "$TEXT" | wc -w) mots)" -i edit-copy
