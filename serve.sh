#!/bin/bash

# Serveur HTTP local instantané depuis un dossier
# Usage: ./serve.sh [dossier] [port]
# Exemples:
#   ./serve.sh                  # sert le dossier courant sur le port 8080
#   ./serve.sh ~/Documents      # sert un dossier spécifique
#   ./serve.sh . 9000           # port personnalisé
# Dépendances: python3 (ou python2 en fallback)

DIR="${1:-.}"
PORT="${2:-8080}"

if [ ! -d "$DIR" ]; then
    echo "Dossier introuvable : $DIR"
    exit 1
fi

cd "$DIR" || exit 1

# Récupérer l'IP locale pour partage réseau
LOCAL_IP=$(ip -4 addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | head -1)

echo "Serveur HTTP démarré"
echo "  Local   : http://localhost:$PORT"
[ -n "$LOCAL_IP" ] && echo "  Réseau  : http://$LOCAL_IP:$PORT"
echo "  Dossier : $(pwd)"
echo "  (Ctrl+C pour arrêter)"
echo ""

if command -v python3 &>/dev/null; then
    python3 -m http.server "$PORT"
elif command -v python &>/dev/null; then
    python -m SimpleHTTPServer "$PORT"
else
    echo "Erreur: python3 non installé"
    exit 1
fi
