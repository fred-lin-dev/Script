#!/usr/bin/env bash
# =============================================================================
# mirror.sh — Mirror complet d'un site web (statique + vidéos)
# Usage : ./mirror.sh <URL> [cookies.txt]
# Exemple : ./mirror.sh https://monsite.com cookies.txt
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Arguments & config
# -----------------------------------------------------------------------------
URL="${1:?Usage: $0 <URL> [cookies.txt]}"
COOKIES="${2:-}"

# Dérive le nom de domaine depuis l'URL (ex: monsite.com)
DOMAIN=$(echo "$URL" | sed -E 's|https?://([^/]+).*|\1|')

# Dossier de sortie pour les vidéos
VIDEO_DIR="videos"

# -----------------------------------------------------------------------------
# Vérification des dépendances
# -----------------------------------------------------------------------------
for cmd in wget yt-dlp grep sort; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "[ERREUR] '$cmd' n'est pas installé." >&2
    exit 1
  fi
done

# -----------------------------------------------------------------------------
# Construction des options cookies (optionnel)
# -----------------------------------------------------------------------------
WGET_COOKIES=()
YTDLP_COOKIES=()

if [[ -n "$COOKIES" ]]; then
  if [[ ! -f "$COOKIES" ]]; then
    echo "[ERREUR] Fichier cookies introuvable : $COOKIES" >&2
    exit 1
  fi
  WGET_COOKIES=(--load-cookies "$COOKIES" --keep-session-cookies)
  YTDLP_COOKIES=(--cookies "$COOKIES")
fi

# -----------------------------------------------------------------------------
# ÉTAPE 1 — Mirror statique avec wget
# -----------------------------------------------------------------------------
echo ""
echo "====================================================="
echo " ÉTAPE 1/2 — Mirror statique : $URL"
echo "====================================================="
echo ""

wget \
  "${WGET_COOKIES[@]}" \
  --recursive \
  --level=inf \
  --page-requisites \
  --adjust-extension \
  --convert-links \
  --no-parent \
  --content-disposition \
  --domains "$DOMAIN" \
  --accept-regex '\.(html?|pdf|docx?|xlsx?|zip|png|jpe?g|gif|webp|svg)(\?.*)?$' \
  --reject-regex '(\.m3u8|\.ts|\.mpd|watch\?v=|/embed/)' \
  --wait=1 \
  --random-wait \
  --tries=3 \
  --timeout=30 \
  -e robots=off \
  "$URL"

echo ""
echo "[OK] Mirror statique terminé."

# -----------------------------------------------------------------------------
# ÉTAPE 2 — Extraction et téléchargement des vidéos avec yt-dlp
# -----------------------------------------------------------------------------
echo ""
echo "====================================================="
echo " ÉTAPE 2/2 — Téléchargement des vidéos : $DOMAIN/"
echo "====================================================="
echo ""

mkdir -p "$VIDEO_DIR"

# Extrait toutes les URLs trouvées dans les fichiers téléchargés,
# déduplique, puis laisse yt-dlp filtrer ce qu'il sait gérer.
URL_COUNT=$(grep -roh 'https://[^ "<]*' "$DOMAIN/" 2>/dev/null | sort -u | wc -l)
echo "[INFO] $URL_COUNT URLs uniques trouvées, envoi à yt-dlp..."
echo ""

grep -roh 'https://[^ "<]*' "$DOMAIN/" 2>/dev/null \
  | sort -u \
  | yt-dlp \
      "${YTDLP_COOKIES[@]}" \
      --batch-file - \
      --ignore-errors \
      --no-warnings \
      -o "$VIDEO_DIR/%(title)s.%(ext)s"

echo ""
echo "[OK] Téléchargement vidéos terminé."

# -----------------------------------------------------------------------------
# Résumé final
# -----------------------------------------------------------------------------
echo ""
echo "====================================================="
echo " RÉSUMÉ"
echo "====================================================="
STATIC_COUNT=$(find "$DOMAIN/" -type f 2>/dev/null | wc -l)
VIDEO_COUNT=$(find "$VIDEO_DIR/" -type f 2>/dev/null | wc -l)
echo " Fichiers statiques : $STATIC_COUNT  →  ./$DOMAIN/"
echo " Vidéos             : $VIDEO_COUNT  →  ./$VIDEO_DIR/"
echo "====================================================="
echo ""
