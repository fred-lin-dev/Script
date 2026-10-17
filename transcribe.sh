#!/bin/bash

# Transcription d'un fichier audio/vidéo local OU d'une URL (YouTube, etc.)
# avec whisper.cpp. Produit un .txt et un .vtt dans un dossier horodaté.
#
# Usage: ./transcribe.sh <fichier|URL> [langue]
# Langues (ISO 639-1) : fr=français  en=anglais  zh=chinois  ja=japonais  ko=coréen
#                       auto = détection sur les 30 premières secondes (défaut)
# Attention : zh/ja/ko, pas cn/jp/kr — ce sont des codes pays, Whisper les refuse.
# Exemples:
#   ./transcribe.sh video.mp4 fr
#   ./transcribe.sh memo.m4a
#   ./transcribe.sh https://youtu.be/xxx en
#
# Modèle : large-v3 par défaut (WER français ~7,8 % contre ~30,5 % pour base).
# Surchargeable pour privilégier la vitesse :
#   WHISPER_MODEL=~/.local/share/whisper.cpp/models/ggml-base.bin ./transcribe.sh memo.m4a

set -euo pipefail

INPUT="${1:-}"
WLANG="${2:-auto}"
MODEL="${WHISPER_MODEL:-$HOME/.local/share/whisper.cpp/models/ggml-large-v3.bin}"

if [ -z "$INPUT" ]; then
    echo "Usage: $0 <fichier|URL> [langue]"
    echo "  langues : fr (français)  en (anglais)  zh (chinois)  ja (japonais)  ko (coréen)"
    echo "            auto = détection automatique (défaut)"
    exit 1
fi

# Confusions fréquentes : ce sont des codes pays, pas des codes langue. On refuse
# tout de suite plutôt qu'après le téléchargement et une heure de transcription.
case "$WLANG" in
    cn) echo "Erreur : 'cn' est le code pays. Pour le chinois, utilise : zh"; exit 1 ;;
    jp) echo "Erreur : 'jp' est le code pays. Pour le japonais, utilise : ja"; exit 1 ;;
    kr) echo "Erreur : 'kr' est le code pays. Pour le coréen, utilise : ko"; exit 1 ;;
esac

need() {
    command -v "$1" >/dev/null 2>&1 || { echo "Erreur : $1 non installé"; exit 1; }
}

need ffmpeg
need whisper-cli

if [ ! -f "$MODEL" ]; then
    echo "Erreur : modèle whisper introuvable : $MODEL"
    exit 1
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

if [[ "$INPUT" =~ ^https?:// ]]; then
    need yt-dlp
    echo "Téléchargement de l'audio..."
    # --postprocessor-args donne directement le 16 kHz mono attendu par
    # whisper.cpp : pas besoin de repasser derrière avec ffmpeg.
    yt-dlp \
        --no-playlist \
        --extract-audio \
        --audio-format wav \
        --postprocessor-args "ExtractAudio:-ar 16000 -ac 1 -c:a pcm_s16le" \
        --output "$WORK/%(title)s.%(ext)s" \
        "$INPUT"

    AUDIO=$(find "$WORK" -maxdepth 1 -name '*.wav' -print -quit)
    if [ -z "$AUDIO" ]; then
        echo "Erreur : aucun audio récupéré depuis l'URL"
        exit 1
    fi
    BASENAME=$(basename "$AUDIO" .wav)
else
    if [ ! -f "$INPUT" ]; then
        echo "Erreur : fichier introuvable : $INPUT"
        exit 1
    fi
    BASENAME=$(basename "$INPUT" | sed 's/\.[^.]*$//')
    AUDIO="$WORK/audio.wav"
    echo "Conversion au format Whisper (16 kHz mono)..."
    ffmpeg -i "$INPUT" -ar 16000 -ac 1 -c:a pcm_s16le "$AUDIO" -hide_banner -loglevel error
fi

OUTPUT_DIR="Transcription_${BASENAME}_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTPUT_DIR"

echo "Transcription en cours (langue: $WLANG)..."
whisper-cli -m "$MODEL" -f "$AUDIO" -l "$WLANG" -otxt -ovtt -of "$OUTPUT_DIR/$BASENAME"

# On garde l'audio converti : utile pour réécouter un passage douteux
mv "$AUDIO" "$OUTPUT_DIR/${BASENAME}.wav"

echo ""
echo "Terminé !"
echo "Dossier  : $OUTPUT_DIR"
echo "Fichiers : ${BASENAME}.txt  ${BASENAME}.vtt  ${BASENAME}.wav"
echo "(réécoute : mpv \"$OUTPUT_DIR/${BASENAME}.wav\")"
