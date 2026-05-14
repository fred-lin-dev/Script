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
for cmd in wget grep sort; do
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

# Supprime le dossier du domaine s'il existait déjà pour repartir propre
if [[ -d "$DOMAIN" ]]; then
  echo "[INFO] Dossier existant '$DOMAIN/' supprimé pour un mirror propre."
  rm -rf "$DOMAIN"
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
# ÉTAPE 2 — Serveur local SPA (pour sites JS/React/Next.js)
# -----------------------------------------------------------------------------
echo ""
echo "====================================================="
echo " ÉTAPE 2/3 — Génération du serveur local SPA"
echo "====================================================="
echo ""

# Détecte si le site est une SPA (body vide, pas de __NEXT_DATA__ en dur)
IS_SPA=false
if grep -q 'id="__NEXT_DATA__"' "$DOMAIN/index.html" 2>/dev/null; then
  : # SSR/SSG : contenu dans le HTML, pas besoin de serveur
elif grep -qE '<script[^>]+src=[^>]+\.js' "$DOMAIN/index.html" 2>/dev/null; then
  # Vérifie si le body est essentiellement vide (SPA CSR)
  BODY_TEXT=$(grep -oP '(?<=<body)[^<]*(<[^/][^>]*>[^<]*)*' "$DOMAIN/index.html" 2>/dev/null | wc -c)
  [[ "$BODY_TEXT" -lt 500 ]] && IS_SPA=true
fi

if $IS_SPA; then
  cat > "$DOMAIN/serve.py" << 'PYEOF'
#!/usr/bin/env python3
"""
Serveur HTTP local avec routage SPA (React/Next.js).
Usage : python3 serve.py [port]
"""
import http.server, os, sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 3000

class SPAHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        raw = self.path.split("?")[0].rstrip("/") or "/"
        path = self.translate_path(raw)
        if os.path.isfile(path):
            pass
        elif os.path.isfile(path + ".html"):
            self.path = raw + ".html"
        elif os.path.isfile(os.path.join(path, "index.html")):
            self.path = raw + "/index.html"
        else:
            self.path = "/index.html"
        super().do_GET()

    def log_message(self, fmt, *args):
        print(f"  {args[0]}  {args[1]}")

os.chdir(os.path.dirname(os.path.abspath(__file__)))
print(f"\n  Ouvre : http://localhost:{PORT}\n  (Ctrl+C pour arrêter)\n")
http.server.HTTPServer(("", PORT), SPAHandler).serve_forever()
PYEOF
  chmod +x "$DOMAIN/serve.py"
  echo "[OK] Serveur SPA généré : ./$DOMAIN/serve.py"
  echo "[INFO] Ce site est une SPA (React/Next.js) — les pages sont vides"
  echo "       sans exécution JavaScript. Lance le serveur pour le consulter :"
  echo ""
  echo "       python3 ./$DOMAIN/serve.py"
  echo ""
else
  echo "[INFO] Site statique classique — ouverture directe des .html possible."
fi

# -----------------------------------------------------------------------------
# ÉTAPE 3 — Téléchargement des vidéos (YouTube/Vimeo) si présentes
# -----------------------------------------------------------------------------
echo ""
echo "====================================================="
echo " ÉTAPE 3/3 — Recherche de vidéos hébergées : $DOMAIN/"
echo "====================================================="
echo ""

mkdir -p "$VIDEO_DIR"

VIDEO_URLS=$(grep -roh 'https://[^ "<]*' "$DOMAIN/" 2>/dev/null \
  | grep -E '(youtube\.com/watch|youtu\.be/|vimeo\.com/[0-9]|dailymotion\.com/video)' \
  | sort -u)

if [[ -z "$VIDEO_URLS" ]]; then
  echo "[INFO] Aucune vidéo hébergée (YouTube/Vimeo/…) détectée."
else
  VIDEO_COUNT_DL=$(echo "$VIDEO_URLS" | wc -l)
  echo "[INFO] $VIDEO_COUNT_DL URL(s) vidéo trouvée(s), téléchargement..."
  echo ""
  if ! command -v yt-dlp &>/dev/null; then
    echo "[AVERTISSEMENT] yt-dlp non installé, vidéos ignorées." >&2
  else
    echo "$VIDEO_URLS" | yt-dlp \
        "${YTDLP_COOKIES[@]}" \
        --batch-file - \
        --ignore-errors \
        --no-warnings \
        -o "$VIDEO_DIR/%(title)s.%(ext)s"
    echo ""
    echo "[OK] Téléchargement vidéos terminé."
  fi
fi

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
if $IS_SPA; then
  echo ""
  echo " *** Site SPA — lancer le serveur local pour consulter : ***"
  echo "     python3 ./$DOMAIN/serve.py"
fi
echo "====================================================="
echo ""
