#!/bin/bash

# Résumé système rapide : CPU, RAM, disque, GPU, réseau, batterie, écran
# Usage: ./sys_info.sh
# Fonctionne sur tout PC Linux (laptop/desktop, avec ou sans batterie)

line() { printf '%-12s %s\n' "$1" "$2"; }

echo "=== Système ==="

# Machine
if [ -f /sys/class/dmi/id/product_name ]; then
    line "MACHINE:" "$(cat /sys/class/dmi/id/product_name 2>/dev/null) $(cat /sys/class/dmi/id/product_version 2>/dev/null)"
fi

# OS + kernel
line "OS:" "$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')"
line "KERNEL:" "$(uname -r)"
line "UPTIME:" "$(uptime -p 2>/dev/null || uptime)"

echo ""
echo "=== Matériel ==="

# CPU
if command -v lscpu &>/dev/null; then
    line "CPU:" "$(lscpu | grep 'Model name' | sed 's/Model name:\s*//')"
    line "CŒURS:" "$(lscpu | grep '^CPU(s):' | awk '{print $2}') threads"
fi

# RAM
if command -v free &>/dev/null; then
    read -r total used <<< "$(free -h | awk '/^Mem:/ {print $2, $3}')"
    line "RAM:" "$used / $total utilisés"
fi

# Disques
echo ""
echo "=== Stockage ==="
if command -v lsblk &>/dev/null; then
    lsblk -o NAME,SIZE,TYPE,MODEL,TRAN 2>/dev/null | grep disk
fi

# GPU
echo ""
echo "=== Affichage ==="
if command -v lspci &>/dev/null; then
    lspci | grep -i 'vga\|3d\|display' | sed 's/.*: //' | while read -r gpu; do
        line "GPU:" "$gpu"
    done
fi

# Résolution écran
if command -v xrandr &>/dev/null && [ -n "$DISPLAY" ]; then
    line "RÉSOLUTION:" "$(xrandr 2>/dev/null | grep ' connected' | grep -o '[0-9]*x[0-9]*' | head -1)"
elif ls /sys/class/drm/*/modes &>/dev/null 2>&1; then
    res=$(cat /sys/class/drm/*/modes 2>/dev/null | head -1)
    [ -n "$res" ] && line "RÉSOLUTION:" "$res"
fi

# Réseau
echo ""
echo "=== Réseau ==="
if command -v lspci &>/dev/null; then
    lspci | grep -i 'network\|wireless\|ethernet' | sed 's/.*: //' | while read -r net; do
        line "CARTE:" "$net"
    done
fi
if command -v ip &>/dev/null; then
    ip -4 addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | while read -r addr; do
        line "IP:" "$addr"
    done
fi

# Batterie (seulement si présente)
echo ""
if command -v upower &>/dev/null; then
    bat=$(upower -e 2>/dev/null | grep battery | head -1)
    if [ -n "$bat" ]; then
        echo "=== Batterie ==="
        upower -i "$bat" 2>/dev/null | grep -E 'model|capacity|technology|state|percentage' | sed 's/^\s*//' | while IFS=: read -r key val; do
            line "$(echo "$key" | tr '[:lower:]' '[:upper:]'):" "$(echo "$val" | xargs)"
        done
    fi
fi
