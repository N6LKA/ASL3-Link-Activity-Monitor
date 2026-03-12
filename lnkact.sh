#!/bin/bash
# =============================================================================
# lnkact - Control script for ASL3 Link Activity Monitor
#
# Usage:
#   lnkact enable   - Re-enable the monitor after disabling
#   lnkact disable  - Disable the monitor (resets suppressed)
#   lnkact status   - Show current monitor status
# =============================================================================

INSTALL_DIR="/etc/asterisk/scripts/lnkact-monitor"
STATE_FILE="$INSTALL_DIR/lnkact-state"
DISABLE_FLAG="$INSTALL_DIR/lnkact-disabled"

# --- Helper: format seconds as human readable ---
format_seconds() {
    local secs=$1
    local h=$(( secs / 3600 ))
    local m=$(( (secs % 3600) / 60 ))
    local s=$(( secs % 60 ))
    if [[ "$h" -gt 0 ]]; then
        printf "%dh %dm %ds" "$h" "$m" "$s"
    elif [[ "$m" -gt 0 ]]; then
        printf "%dm %ds" "$m" "$s"
    else
        printf "%ds" "$s"
    fi
}

cmd="${1:-status}"

case "$cmd" in

    enable)
        if [[ ! -f "$DISABLE_FLAG" ]]; then
            echo "Monitor is already enabled."
        else
            rm -f "$DISABLE_FLAG"
            echo "Monitor enabled - resets will resume."
        fi
        ;;

    disable)
        if [[ -f "$DISABLE_FLAG" ]]; then
            echo "Monitor is already disabled."
        else
            touch "$DISABLE_FLAG"
            echo "Monitor disabled - resets suppressed until re-enabled."
        fi
        ;;

    status)
        # Check if service is running
        if ! systemctl is-active --quiet lnkact-monitor; then
            echo ""
            echo "  ASL3 Link Activity Monitor"
            echo "  Status: STOPPED (service is not running)"
            echo ""
            exit 0
        fi

        # Check for state file
        if [[ ! -f "$STATE_FILE" ]]; then
            echo ""
            echo "  ASL3 Link Activity Monitor"
            echo "  Status: Running (state file not yet available)"
            echo ""
            exit 0
        fi

        # Load state
        source "$STATE_FILE"

        # Calculate uptime
        now=$(date +%s)
        uptime_secs=$(( now - START_TIME ))
        uptime_str=$(format_seconds "$uptime_secs")

        # Format remaining time
        remaining_str=$(format_seconds "$REMAINING")

        # Disabled status
        if [[ "$DISABLED" == "yes" ]]; then
            status_str="DISABLED (resets suppressed)"
        elif [[ "$IN_BLACKOUT" == "yes" ]]; then
            status_str="Running (blackout window active - resets suppressed)"
        else
            status_str="Running"
        fi

        # Blackout info
        if [[ -n "$BLACKOUT_START" && -n "$BLACKOUT_END" ]]; then
            blackout_str="${BLACKOUT_START} - ${BLACKOUT_END}"
            if [[ "$IN_BLACKOUT" == "yes" ]]; then
                blackout_str="$blackout_str  [ACTIVE]"
            fi
        else
            blackout_str="Not configured"
        fi

        # Scheduled resets
        if [[ -n "$SCHEDULED_RESETS" ]]; then
            sched_str="$SCHEDULED_RESETS"
        else
            sched_str="Not configured"
        fi

        echo ""
        echo "  ASL3 Link Activity Monitor - Node $NODE"
        echo "  ----------------------------------------"
        echo "  Status:          $status_str"
        echo "  Uptime:          $uptime_str"
        echo "  Timeout:         $(format_seconds "$INACT_TIMEOUT")"
        echo "  Time remaining:  $remaining_str until reset"
        echo "  Resets today:    $RESET_COUNT"
        echo "  Blackout window: $blackout_str"
        echo "  Scheduled resets: $sched_str"
        echo ""
        ;;

    *)
        echo "Usage: lnkact {enable|disable|status}"
        exit 1
        ;;
esac
