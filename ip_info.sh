#!/bin/bash

# Afficher l'IP publique et locale + informations de géolocalisation
# Usage: ./ip_info.sh
# Dépendances: curl

command -v curl &>/dev/null || { echo "Erreur: curl non installé"; exit 1; }

echo "=== IP Locale ==="
if command -v ip &>/dev/null; then
    ip -4 addr show | grep 'inet ' | grep -v '127.0.0.1' | while read -r line; do
        iface=$(echo "$line" | awk '{print $NF}')
        addr=$(echo "$line" | awk '{print $2}')
        printf "  %-10s %s\n" "$iface" "$addr"
    done
fi

echo ""
echo "=== IP Publique ==="
INFO=$(curl -s --max-time 5 "https://ipinfo.io/json" 2>/dev/null)

if [ -z "$INFO" ]; then
    echo "  Impossible de récupérer l'IP publique (pas de connexion ?)"
    exit 1
fi

parse() { echo "$INFO" | grep "\"$1\"" | cut -d'"' -f4; }

IP=$(parse ip)
CITY=$(parse city)
REGION=$(parse region)
COUNTRY=$(parse country)
ORG=$(parse org)
TIMEZONE=$(parse timezone)

printf "  %-12s %s\n" "IP:"       "$IP"
printf "  %-12s %s, %s (%s)\n" "Lieu:"    "$CITY" "$REGION" "$COUNTRY"
printf "  %-12s %s\n" "FAI:"      "$ORG"
printf "  %-12s %s\n" "Timezone:" "$TIMEZONE"
