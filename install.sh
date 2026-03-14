#!/bin/bash
# =============================================================================
# install.sh - Installer for ASL3 Link Activity Monitor
# https://github.com/N6LKA/asl3-link-activity-monitor
# =============================================================================

INSTALL_DIR="/etc/asterisk/scripts/lnkact-monitor"
SCRIPT_FILE="$INSTALL_DIR/lnkact-monitor.sh"
CONTROL_FILE="$INSTALL_DIR/lnkact.sh"
CONF_FILE="$INSTALL_DIR/lnkact-monitor.conf"
SERVICE_FILE="/etc/systemd/system/lnkact-monitor.service"
SYMLINK="/usr/local/bin/lnkact"
REPO="https://raw.githubusercontent.com/N6LKA/asl3-link-activity-monitor/main"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "=============================================="
echo "  ASL3 Link Activity Monitor - Installer"
echo "  https://github.com/N6LKA/asl3-link-activity-monitor"
echo "=============================================="
echo ""

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}ERROR: This installer must be run as root or with sudo.${NC}"
    exit 1
fi

# --- Check for existing install ---
if [[ -f "$CONF_FILE" ]]; then
    echo -e "${YELLOW}Existing installation detected.${NC}"
    echo "This will update the scripts only. Your configuration file will NOT be changed."
    echo ""
    read -rp "Continue with update? (y/n): " confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && echo "Aborted." && exit 0
    PRESERVE_CONF=true

    echo "Stopping service..."
    systemctl stop lnkact-monitor

    if [[ -f "$SCRIPT_FILE" ]]; then
        BACKUP="$SCRIPT_FILE.bak.$(date +%Y%m%d%H%M%S)"
        cp "$SCRIPT_FILE" "$BACKUP"
        echo "Backup created: $BACKUP"
    fi
else
    PRESERVE_CONF=false
fi

echo ""
echo "--- Downloading files ---"

# --- Create install directory with correct permissions ---
mkdir -p "$INSTALL_DIR"
chown root:asterisk "$INSTALL_DIR"
chmod 775 "$INSTALL_DIR"

# --- Download main script ---
echo "Downloading lnkact-monitor.sh..."
curl -fsSL "$REPO/lnkact-monitor.sh" -o "$SCRIPT_FILE"
if [[ $? -ne 0 ]]; then
    echo -e "${RED}ERROR: Failed to download lnkact-monitor.sh${NC}"
    if [[ -n "$BACKUP" && -f "$BACKUP" ]]; then
        echo "Restoring backup..."
        cp "$BACKUP" "$SCRIPT_FILE"
        systemctl start lnkact-monitor
    fi
    exit 1
fi
chmod +x "$SCRIPT_FILE"

# --- Download control script ---
echo "Downloading lnkact.sh..."
curl -fsSL "$REPO/lnkact.sh" -o "$CONTROL_FILE"
if [[ $? -ne 0 ]]; then
    echo -e "${RED}ERROR: Failed to download lnkact.sh${NC}"
    exit 1
fi
chmod +x "$CONTROL_FILE"

# --- Create symlink for lnkact command ---
ln -sf "$CONTROL_FILE" "$SYMLINK"
echo "Control command available: lnkact enable|disable|status"

# --- Download audio warning files ---
echo "Downloading 30seconds-reset.ul..."
curl -fsSL "$REPO/30seconds-reset.ul" -o "$INSTALL_DIR/30seconds-reset.ul"
if [[ $? -ne 0 ]]; then
    echo -e "${RED}ERROR: Failed to download 30seconds-reset.ul${NC}"
    exit 1
fi
chown root:asterisk "$INSTALL_DIR/30seconds-reset.ul"
chmod 644 "$INSTALL_DIR/30seconds-reset.ul"

echo "Downloading 30seconds-reset.txt..."
curl -fsSL "$REPO/30seconds-reset.txt" -o "$INSTALL_DIR/30seconds-reset.txt"
if [[ $? -ne 0 ]]; then
    echo -e "${RED}ERROR: Failed to download 30seconds-reset.txt${NC}"
    exit 1
fi
chown root:asterisk "$INSTALL_DIR/30seconds-reset.txt"
chmod 644 "$INSTALL_DIR/30seconds-reset.txt"

# --- Download service file ---
echo "Downloading lnkact-monitor.service..."
curl -fsSL "$REPO/lnkact-monitor.service" -o "$SERVICE_FILE"
if [[ $? -ne 0 ]]; then
    echo -e "${RED}ERROR: Failed to download lnkact-monitor.service${NC}"
    exit 1
fi

echo ""

# --- Create conf file if it doesn't exist ---
if [[ "$PRESERVE_CONF" == "false" ]]; then
    echo "--- Configuration Setup ---"
    echo "Please answer the following questions to configure the monitor."
    echo "You can change any of these later by editing: $CONF_FILE"
    echo ""

    while true; do
        read -rp "Enter your ASL3 node number: " NODE
        NODE=$(echo "$NODE" | tr -d ' ')
        [[ -n "$NODE" ]] && break
        echo -e "${RED}Node number is required.${NC}"
    done

    read -rp "Enter permanent/hub node(s) to stay connected [leave blank if none]: " PERMANENT_NODES
    read -rp "Enter node(s) to reconnect to after reset [leave blank if none]: " RECONNECT_NODES
    read -rp "Inactivity timeout in seconds [default: 900 = 15 min]: " INACT_TIMEOUT
    INACT_TIMEOUT=${INACT_TIMEOUT:-900}
    read -rp "Path to connection log file [default: /var/log/asterisk/connectlog, blank to disable]: " CONNECT_LOG
    CONNECT_LOG=${CONNECT_LOG:-/var/log/asterisk/connectlog}

    echo ""
    echo "--- Writing configuration file ---"

    cat > "$CONF_FILE" << EOF
# =============================================================================
# lnkact-monitor.conf - Configuration for ASL3 Link Activity Monitor
#
# After making changes, restart the service:
#   systemctl restart lnkact-monitor
#
# For connection logging setup, see:
#   https://github.com/N6LKA/asl3-connection-log
#
# Full documentation:
#   https://github.com/N6LKA/asl3-link-activity-monitor
# =============================================================================

# --- Node ---
# Node number to monitor (required)
NODE="$NODE"

# --- Inactivity Timer ---
# Seconds of RF inactivity before reset (900 = 15 min)
INACT_TIMEOUT=$INACT_TIMEOUT

# How often to check activity in seconds
POLL_INTERVAL=2

# --- Warning ---
# Warning mode: "tts" = text-to-speech, "file" = pre-recorded audio, "none" = silent
WARN_MODE="tts"

# Path to pre-recorded warning file (no extension) - used if WARN_MODE=file
WARN_AUDIO="$INSTALL_DIR/30seconds-reset"

# TTS warning text - used if WARN_MODE=tts
WARN_TTS_TEXT="Inactivity Warning! Node connections will reset in 30 seconds."

# Seconds before reset to play warning
WARN_LEAD=30

# Extra seconds offset for file playback timing
WARN_OFFSET_FILE=7

# Extra seconds offset for TTS processing + playback timing
WARN_OFFSET_TTS=7

# --- Connection Log ---
# ASL3 does NOT have a native connection log. See:
#   https://github.com/N6LKA/asl3-connection-log
# Leave blank to disable connection log monitoring.
CONNECT_LOG="$CONNECT_LOG"

# --- Permanent / Always-Connected Nodes ---
# Space-separated list of nodes that are always connected.
# Reset is skipped if ONLY these nodes are connected.
# Leave blank to always reset regardless of connected nodes.
PERMANENT_NODES="$PERMANENT_NODES"

# --- Blackout Window ---
# During the blackout window, resets and warnings are suppressed entirely.
# Uses 24-hour format (HH:MM). Leave both blank to disable.
# Midnight-spanning windows are supported (e.g. 22:00 to 06:00).
# Example: BLACKOUT_START="19:00" BLACKOUT_END="21:00"
BLACKOUT_START=""
BLACKOUT_END=""

# --- Scheduled Resets ---
# Space-separated list of HH:MM (24-hour) times to force a reset daily.
# Warning plays before each scheduled reset. Leave blank to disable.
# Example: SCHEDULED_RESETS="06:00 16:00"
SCHEDULED_RESETS=""

# --- Reset Actions ---
# Wrap reset in telemetry off/on (cop 34/35): yes or no
USE_TELEMETRY="yes"

# Disconnect all nodes before reconnecting: yes or no
DISCONNECT_ALL="yes"

# Space-separated list of nodes to reconnect after reset.
# Leave blank to not reconnect to any node after reset.
RECONNECT_NODES="$RECONNECT_NODES"

# Play TTS announcement after reset: yes or no
ANNOUNCE="yes"

# TTS text spoken after reset completes
ANNOUNCE_TEXT="Connection Reset"
EOF

    echo -e "${GREEN}Configuration file created: $CONF_FILE${NC}"
fi

# --- Enable and start service ---
echo ""
echo "--- Enabling and starting service ---"
systemctl daemon-reload
systemctl enable lnkact-monitor > /dev/null 2>&1
systemctl restart lnkact-monitor

sleep 2
if systemctl is-active --quiet lnkact-monitor; then
    echo -e "${GREEN}Service is running successfully.${NC}"
    [[ -n "$BACKUP" && -f "$BACKUP" ]] && rm -f "$BACKUP"
else
    echo -e "${RED}WARNING: Service did not start.${NC}"
    if [[ -n "$BACKUP" && -f "$BACKUP" ]]; then
        echo "Restoring previous version..."
        cp "$BACKUP" "$SCRIPT_FILE"
        systemctl start lnkact-monitor
        echo "Previous version restored. Check logs with:"
    else
        echo "Check logs with:"
    fi
    echo "  journalctl -u lnkact-monitor -f"
fi

echo ""
echo "=============================================="
if [[ "$PRESERVE_CONF" == "true" ]]; then
    echo -e "${GREEN}Update complete!${NC}"
    echo ""
    echo "Your configuration file was not modified."
    echo "If new options were added, they will be appended"
    echo "to your conf file automatically on next start."
    echo "Check for new options with:"
    echo "  journalctl -u lnkact-monitor | grep 'NEW config'"
else
    echo -e "${GREEN}Installation complete!${NC}"
    echo ""
    echo "Edit the conf file to configure optional features:"
    echo "  - Blackout windows"
    echo "  - Scheduled resets"
    echo "  - Warning mode (tts/file/none)"
    echo "  - And more..."
fi
echo ""
echo "Configuration file: $CONF_FILE"
echo "Scripts directory:  $INSTALL_DIR"
echo ""
echo "Service commands:"
echo "  systemctl start|stop|restart lnkact-monitor"
echo "  journalctl -u lnkact-monitor -f"
echo ""
echo "Control commands:"
echo "  lnkact enable"
echo "  lnkact disable"
echo "  lnkact status"
echo "=============================================="
echo ""
