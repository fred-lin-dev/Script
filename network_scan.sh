#!/bin/bash

# Scanner les appareils connectés sur le réseau local
# Usage: ./network_scan.sh [plage_réseau]
# Exemples:
#   ./network_scan.sh                  # détecte automatiquement le réseau
#   ./network_scan.sh 192.168.1.0/24   # plage explicite
# Dépendances: nmap

command -v nmap &>/dev/null || { echo "Erreur: nmap non installé (sudo pacman -S nmap)"; exit 1; }

# Détection automatique du réseau local
if [ -z "$1" ]; then
    NETWORK=$(ip -4 route | grep -v default | grep 'src' | awk '{print $1}' | head -1)
    if [ -z "$NETWORK" ]; then
        echo "Impossible de détecter le réseau automatiquement."
        echo "Usage: $0 <plage_réseau> (ex: 192.168.1.0/24)"
        exit 1
    fi
else
    NETWORK="$1"
fi

echo "Scan du réseau : $NETWORK"
echo "Patientez..."
echo ""

# Scan rapide : découverte des hôtes actifs + nom + MAC
nmap -sn "$NETWORK" 2>/dev/null | awk '
    /Nmap scan report for/ {
        host = $NF
        gsub(/[()]/, "", host)
        name = ""
        if ($5 ~ /[a-zA-Z]/) { name = $5; host = $6; gsub(/[()]/, "", host) }
        printf "%-18s %s\n", host, name
    }
    /MAC Address/ {
        mac = $3
        vendor = ""
        for (i=4; i<=NF; i++) vendor = vendor " " $i
        printf "%-18s MAC: %s%s\n", "", mac, vendor
        print ""
    }
'

echo "Scan terminé."
