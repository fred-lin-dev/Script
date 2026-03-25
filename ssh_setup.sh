#!/bin/bash

# Générer une clé SSH et l'installer sur un serveur distant
# Usage:
#   ./ssh_setup.sh                        # générer une clé seulement
#   ./ssh_setup.sh user@host              # générer + copier sur le serveur
#   ./ssh_setup.sh user@host -p 2222      # port SSH personnalisé
#   ./ssh_setup.sh --list                 # lister les clés existantes
# Dépendances: ssh, ssh-keygen, ssh-copy-id

KEY_DIR="$HOME/.ssh"
DEFAULT_TYPE="ed25519"

usage() {
    echo "Usage:"
    echo "  $0                        # générer une clé"
    echo "  $0 user@host              # générer + copier sur le serveur"
    echo "  $0 user@host -p 2222      # port SSH personnalisé"
    echo "  $0 --list                 # lister les clés existantes"
}

list_keys() {
    echo "=== Clés SSH existantes ==="
    for pub in "$KEY_DIR"/*.pub; do
        [ -f "$pub" ] || continue
        key="${pub%.pub}"
        fingerprint=$(ssh-keygen -lf "$pub" 2>/dev/null)
        printf "  %s\n    %s\n\n" "$(basename "$pub")" "$fingerprint"
    done
}

if [ "$1" = "--list" ]; then list_keys; exit 0; fi
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then usage; exit 0; fi

TARGET="$1"
PORT="22"
[ "$2" = "-p" ] && PORT="$3"

mkdir -p "$KEY_DIR"
chmod 700 "$KEY_DIR"

# Choisir le nom de la clé
echo "=== Génération de clé SSH ($DEFAULT_TYPE) ==="
echo ""
read -rp "Nom de la clé (défaut: id_ed25519) : " KEY_NAME
KEY_NAME="${KEY_NAME:-id_ed25519}"
KEY_PATH="$KEY_DIR/$KEY_NAME"

if [ -f "$KEY_PATH" ]; then
    echo "La clé '$KEY_PATH' existe déjà."
    read -rp "Écraser ? [o/N] " confirm
    [[ "$confirm" =~ ^[oOyY]$ ]] || { echo "Annulé."; exit 0; }
fi

read -rp "Commentaire (défaut: $USER@$(hostname)) : " COMMENT
COMMENT="${COMMENT:-$USER@$(hostname)}"

ssh-keygen -t "$DEFAULT_TYPE" -C "$COMMENT" -f "$KEY_PATH"

echo ""
echo "Clé générée :"
echo "  Privée  : $KEY_PATH"
echo "  Publique: ${KEY_PATH}.pub"
echo ""
echo "Clé publique :"
cat "${KEY_PATH}.pub"

# Copier sur le serveur si demandé
if [ -n "$TARGET" ]; then
    echo ""
    echo "=== Copie sur $TARGET (port $PORT) ==="
    ssh-copy-id -i "${KEY_PATH}.pub" -p "$PORT" "$TARGET"
    if [ $? -eq 0 ]; then
        echo ""
        echo "Clé installée. Test de connexion :"
        ssh -i "$KEY_PATH" -p "$PORT" "$TARGET" "echo 'Connexion réussie !'"
    else
        echo "Erreur lors de la copie. Vous pouvez le faire manuellement :"
        echo "  ssh-copy-id -i ${KEY_PATH}.pub $TARGET"
    fi
fi
