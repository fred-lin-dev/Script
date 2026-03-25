#!/bin/bash

# Minuteur / Pomodoro en terminal avec notification
# Usage:
#   ./timer.sh 25m              # minuteur simple 25 minutes
#   ./timer.sh 1h30m            # 1h30
#   ./timer.sh 90               # 90 secondes
#   ./timer.sh pomodoro         # cycle pomodoro standard (25/5/25/5/25/15)
# Dépendances: notify-send (libnotify), paplay ou aplay (optionnel pour le son)

ARGS="$*"

parse_duration() {
    local input="$1"
    local total=0
    # Format: 1h30m20s ou juste un nombre (secondes)
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        total="$input"
    else
        [[ "$input" =~ ([0-9]+)h ]] && total=$((total + ${BASH_REMATCH[1]} * 3600))
        [[ "$input" =~ ([0-9]+)m ]] && total=$((total + ${BASH_REMATCH[1]} * 60))
        [[ "$input" =~ ([0-9]+)s ]] && total=$((total + ${BASH_REMATCH[1]}))
    fi
    echo "$total"
}

format_time() {
    local secs="$1"
    printf "%02d:%02d" $((secs / 60)) $((secs % 60))
}

notify() {
    local title="$1" msg="$2"
    command -v notify-send &>/dev/null && notify-send -u normal "$title" "$msg"
    # Son de notification (optionnel)
    command -v paplay &>/dev/null && paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null
}

run_timer() {
    local duration="$1" label="$2"
    local remaining="$duration"

    echo ""
    echo "  ⏱  $label — $(format_time $duration)"
    echo "  (Ctrl+C pour annuler)"
    echo ""

    while [ "$remaining" -gt 0 ]; do
        printf "\r  %s restantes " "$(format_time $remaining)"
        sleep 1
        ((remaining--))
    done

    printf "\r  00:00 — Terminé !        \n"
    notify "⏱ Timer" "$label terminé !"
}

pomodoro() {
    local sessions=(
        "25m:Travail 1"
        "5m:Pause courte"
        "25m:Travail 2"
        "5m:Pause courte"
        "25m:Travail 3"
        "15m:Pause longue"
    )

    echo "=== Pomodoro ==="
    for session in "${sessions[@]}"; do
        local dur="${session%%:*}"
        local label="${session##*:}"
        local secs
        secs=$(parse_duration "$dur")

        notify "🍅 Pomodoro" "Début : $label ($dur)"
        run_timer "$secs" "$label"

        # Pause entre les sessions sauf la dernière
        if [ "$session" != "${sessions[-1]}" ]; then
            read -rp "  Appuie sur Entrée pour continuer..." _
        fi
    done

    echo ""
    echo "=== Cycle Pomodoro terminé ! ==="
    notify "🍅 Pomodoro" "Cycle complet terminé !"
}

# --- Main ---

if [ -z "$ARGS" ]; then
    echo "Usage: $0 <durée> | pomodoro"
    echo "  Exemples: $0 25m | $0 1h30m | $0 90 | $0 pomodoro"
    exit 1
fi

if [ "$ARGS" = "pomodoro" ]; then
    pomodoro
else
    SECS=$(parse_duration "$ARGS")
    if [ "$SECS" -eq 0 ]; then
        echo "Durée invalide : '$ARGS'"
        echo "Formats acceptés : 25m, 1h30m, 90s, 90"
        exit 1
    fi
    run_timer "$SECS" "Timer $ARGS"
fi
