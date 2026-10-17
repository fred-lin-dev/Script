#!/bin/bash

# Convertit un fichier .vtt (ou .srt) en texte brut : supprime l'en-tête, les
# timings, les identifiants de cue et les balises de style.
# Usage: ./vtt_to_txt.sh <fichier.vtt> [fichier_sortie.txt]
# Si pas de fichier de sortie : affiche dans le terminal + copie dans le presse-papiers
# Exemples:
#   ./vtt_to_txt.sh video.vtt
#   ./vtt_to_txt.sh video.vtt transcript.txt

INPUT="$1"
OUTPUT="$2"

if [ -z "$INPUT" ]; then
    echo "Usage: $0 <fichier.vtt|fichier.srt> [fichier_sortie.txt]"
    exit 1
fi

if [ ! -f "$INPUT" ]; then
    echo "Fichier introuvable : $INPUT"
    exit 1
fi

TEXT=$(awk '
    function flush() {
        if (buf == "") return
        # Les sous-titres roulants (YouTube auto) répètent la même ligne : on saute
        if (buf != prev) { print buf; prev = buf }
        buf = ""
    }
    { sub(/\r$/, ""); line[NR] = $0 }
    END {
        for (i = 1; i <= NR; i++) {
            s = line[i]

            # En-tête WEBVTT et ses métadonnées (jusqu'\''à la première ligne vide)
            if (i == 1 && s ~ /WEBVTT/)                  { header = 1; continue }
            if (header) { if (s ~ /^[[:space:]]*$/) header = 0; continue }

            # Blocs NOTE / STYLE / REGION
            if (s ~ /^(NOTE|STYLE|REGION)([[:space:]]|$)/) { block = 1; continue }
            if (block)  { if (s ~ /^[[:space:]]*$/) block = 0;  continue }

            # Ligne de timing (VTT utilise ".", SRT ",", les deux ont "-->")
            if (s ~ /-->/) continue

            # Identifiant de cue : numéro SRT ou nom VTT suivi d'\''un timing
            if (s !~ /^[[:space:]]*$/ && line[i+1] ~ /-->/) continue

            gsub(/<[^>]*>/, "", s)        # <c>, <i>, <v Nom>, <00:00:01.000>
            gsub(/&nbsp;/, " ", s)
            gsub(/&lt;/, "<", s)
            gsub(/&gt;/, ">", s)
            gsub(/&quot;/, "\"", s)
            gsub(/&#39;/, "'"'"'", s)
            gsub(/&amp;/, "\\&", s)       # en dernier
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)

            if (s == "") { flush(); continue }
            buf = (buf == "") ? s : buf " " s
        }
        flush()
    }
' "$INPUT")

if [ -n "$OUTPUT" ]; then
    echo "$TEXT" > "$OUTPUT"
    LINES=$(echo "$TEXT" | wc -l)
    WORDS=$(echo "$TEXT" | wc -w)
    echo "Sauvegardé : $OUTPUT ($WORDS mots, $LINES lignes)"
else
    echo "$TEXT"
    echo ""
    # Copier dans le presse-papiers si disponible
    if command -v xclip &>/dev/null; then
        echo "$TEXT" | xclip -selection clipboard >/dev/null 2>&1
        echo "[Copié dans le presse-papiers]"
    elif command -v wl-copy &>/dev/null; then
        echo "$TEXT" | wl-copy
        echo "[Copié dans le presse-papiers]"
    fi
fi
