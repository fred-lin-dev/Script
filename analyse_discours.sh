#!/bin/bash

# Vérification de l'argument (le lien YouTube)
if [ -z "$1" ]; then
    echo "Usage: ./analyse_discours.sh <URL_YOUTUBE>"
    exit 1
fi

URL=$1
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="Analyse_$TIMESTAMP"

# Création du dossier de travail
mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

echo "📥 Téléchargement de l'audio..."
yt-dlp -x --audio-format wav "$URL" -o "brut.%(ext)s"

echo "🔄 Conversion au format Whisper (16kHz mono)..."
ffmpeg -i brut.wav -ar 16000 -ac 1 -c:a pcm_s16le audio_final.wav -hide_banner -loglevel error

echo "✍️ Transcription en cours (Français + Anglais)..."
# On utilise le modèle base pour un bon équilibre vitesse/précision
# L'option -osrt génère un fichier de sous-titres en plus du texte
# Dans ton script analyse_discours.sh, remplace la ligne whisper par celle-ci :
whisper-cli -m "$HOME/.local/share/whisper.cpp/models/ggml-base.bin" -f audio_final.wav -l auto -otxt -osrt

echo "✅ Terminé !"
echo "Dossier : $OUTPUT_DIR"
echo "Fichiers générés : audio_final.wav.txt et audio_final.wav.srt"
