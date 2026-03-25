#!/bin/bash

# Conversion de fichiers audio en lot
# Usage: ./audio_convert.sh <format_sortie> [dossier] [qualité]
# Formats: mp3, flac, ogg, wav, m4a, opus
# Exemples:
#   ./audio_convert.sh mp3               # convertir tous les audio du dossier courant en mp3
#   ./audio_convert.sh flac ~/Musique    # convertir en flac lossless
#   ./audio_convert.sh mp3 . 192         # mp3 à 192kbps (défaut: 320)
# Dépendances: ffmpeg

FORMAT="${1,,}"
INPUT_DIR="${2:-.}"
QUALITY="${3:-320}"

SUPPORTED_FORMATS="mp3 flac ogg wav m4a opus"

usage() {
    echo "Usage: $0 <format_sortie> [dossier] [qualité_kbps]"
    echo "  Formats supportés : $SUPPORTED_FORMATS"
    echo "  Qualité (pour mp3/ogg/opus) : 128, 192, 256, 320 (défaut: 320)"
    echo ""
    echo "Exemples:"
    echo "  $0 mp3"
    echo "  $0 flac ~/Musique"
    echo "  $0 opus . 128"
}

if [ -z "$FORMAT" ]; then usage; exit 1; fi

if ! echo "$SUPPORTED_FORMATS" | grep -qw "$FORMAT"; then
    echo "Format non supporté : $FORMAT"
    echo "Formats disponibles : $SUPPORTED_FORMATS"
    exit 1
fi

command -v ffmpeg &>/dev/null || { echo "Erreur: ffmpeg non installé (sudo pacman -S ffmpeg)"; exit 1; }

# Collecter tous les fichiers audio
mapfile -t FILES < <(find "$INPUT_DIR" -maxdepth 1 -type f \( \
    -iname "*.mp3" -o -iname "*.flac" -o -iname "*.ogg" -o \
    -iname "*.wav" -o -iname "*.m4a" -o -iname "*.opus" -o \
    -iname "*.aac" -o -iname "*.wma" \) | sort)

if [ ${#FILES[@]} -eq 0 ]; then
    echo "Aucun fichier audio trouvé dans : $INPUT_DIR"
    exit 1
fi

# Filtrer les fichiers qui ne sont pas déjà dans le format cible
TO_CONVERT=()
for f in "${FILES[@]}"; do
    ext="${f##*.}"
    [[ "${ext,,}" != "$FORMAT" ]] && TO_CONVERT+=("$f")
done

if [ ${#TO_CONVERT[@]} -eq 0 ]; then
    echo "Tous les fichiers sont déjà en $FORMAT."
    exit 0
fi

OUTPUT_DIR="$INPUT_DIR/converted_$FORMAT"
mkdir -p "$OUTPUT_DIR"

echo "${#TO_CONVERT[@]} fichier(s) à convertir → $FORMAT"
[ "$FORMAT" != "flac" ] && [ "$FORMAT" != "wav" ] && echo "Qualité : ${QUALITY}kbps"
echo ""

# Options ffmpeg selon le format
get_ffmpeg_opts() {
    case "$1" in
        mp3)  echo "-codec:a libmp3lame -b:a ${QUALITY}k" ;;
        flac) echo "-codec:a flac" ;;
        ogg)  echo "-codec:a libvorbis -b:a ${QUALITY}k" ;;
        wav)  echo "-codec:a pcm_s16le" ;;
        m4a)  echo "-codec:a aac -b:a ${QUALITY}k" ;;
        opus) echo "-codec:a libopus -b:a ${QUALITY}k" ;;
    esac
}

OPTS=$(get_ffmpeg_opts "$FORMAT")
SUCCESS=0
FAIL=0

for f in "${TO_CONVERT[@]}"; do
    BASENAME=$(basename "$f")
    NAME="${BASENAME%.*}"
    OUT="$OUTPUT_DIR/${NAME}.${FORMAT}"

    printf "  %-50s" "$BASENAME"
    # shellcheck disable=SC2086
    if ffmpeg -i "$f" $OPTS "$OUT" -y -loglevel error 2>/dev/null; then
        echo "OK"
        ((SUCCESS++))
    else
        echo "ERREUR"
        ((FAIL++))
    fi
done

echo ""
echo "Terminé : $SUCCESS OK, $FAIL erreur(s)"
echo "Fichiers dans : $OUTPUT_DIR"
