#!/bin/bash

# Transcription d'un fichier audio/vidéo local avec whisper.cpp
# Usage: ./transcribe_local.sh <fichier> [langue]
# Exemple: ./transcribe_local.sh video.mp4 fr

if [ -z "$1" ]; then
    echo "Usage: ./transcribe_local.sh <fichier> [langue]"
    echo "Langues: fr, en, auto (défaut: auto)"
    exit 1
fi

INPUT="$1"
LANG="${2:-auto}"

if [ ! -f "$INPUT" ]; then
    echo "Erreur : fichier introuvable : $INPUT"
    exit 1
fi

BASENAME=$(basename "$INPUT" | sed 's/\.[^.]*$//')
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="Transcription_${BASENAME}_${TIMESTAMP}"
WHISPER_MODEL="$HOME/.local/share/whisper.cpp/models/ggml-base.bin"

mkdir -p "$OUTPUT_DIR"

echo "Conversion au format Whisper (16kHz mono)..."
ffmpeg -i "$INPUT" -ar 16000 -ac 1 -c:a pcm_s16le "$OUTPUT_DIR/audio.wav" -hide_banner -loglevel error

echo "Transcription en cours (langue: $LANG)..."
whisper-cli -m "$WHISPER_MODEL" -f "$OUTPUT_DIR/audio.wav" -l "$LANG" -otxt -osrt

mv "$OUTPUT_DIR/audio.wav.txt" "$OUTPUT_DIR/${BASENAME}.txt" 2>/dev/null
mv "$OUTPUT_DIR/audio.wav.srt" "$OUTPUT_DIR/${BASENAME}.srt" 2>/dev/null

echo "Terminé !"
echo "Dossier : $OUTPUT_DIR"
echo "Fichiers : ${BASENAME}.txt  ${BASENAME}.srt"
