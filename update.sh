#!/bin/bash
# =============================================================================
# update.sh - Updater for ASL3 Link Activity Monitor
# https://github.com/N6LKA/asl3-link-activity-monitor
#
# This script updates ONLY the main script file.
# Your configuration file (lnkact-monitor.conf) is never modified.
# Any new configuration variables added in the update will be automatically
# appended to your conf file with default values on next service start.
# =============================================================================

SCRIPT_DIR="/etc/asterisk/scripts"
SCRIPT_FILE="$SCRIPT_DIR/lnkact-monitor.sh"
CONF_FILE="$SCRIPT_DIR/lnkact-monitor.conf"
REPO="https://raw.githubusercontent.com/N6LKA/asl3-link-activity-monitor/main"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "=============================================="
echo "  ASL3 Link Activity Monitor - Updater"
echo "=============================================="
echo ""

# --- Must run as root ---
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}ERROR: This updater must be run as root.${NC}"
    exit 1
fi

# --- Check for existing install ---
if [[ ! -f "$CONF_FILE" ]]; then
    echo -e "${RED}ERROR: No configuration file found at $CONF_FILE${NC}"
    echo "It looks like the monitor is not installed yet."
    echo "Run the installer instead:"
    echo "  curl -fsSL https://raw.githubusercontent.com/N6LKA/asl3-link-activity-monitor/main/install.sh | bash"
    exit 1
fi

if [[ ! -f "$SCRIPT_FILE" ]]; then
    echo -e "${RED}ERROR: Script file not found at $SCRIPT_FILE${NC}"
    echo "Run the installer instead."
    exit 1
fi

echo "Your configuration file will NOT be modified: $CONF_FILE"
echo ""

# --- Stop service ---
echo "Stopping service..."
systemctl stop lnkact-monitor

# --- Backup existing script ---
BACKUP="$SCRIPT_FILE.bak.$(date +%Y%m%d%H%M%S)"
cp "$SCRIPT_FILE" "$BACKUP"
echo "Backup created: $BACKUP"

# --- Download updated script ---
echo "Downloading updated lnkact-monitor.sh..."
curl -fsSL "$REPO/lnkact-monitor.sh" -o "$SCRIPT_FILE"
if [[ $? -ne 0 ]]; then
    echo -e "${RED}ERROR: Download failed. Restoring backup...${NC}"
    cp "$BACKUP" "$SCRIPT_FILE"
    systemctl start lnkact-monitor
    exit 1
fi
chmod +x "$SCRIPT_FILE"

# --- Download updated service file ---
echo "Downloading updated lnkact-monitor.service..."
curl -fsSL "$REPO/lnkact-monitor.service" -o /etc/systemd/system/lnkact-monitor.service
if [[ $? -ne 0 ]]; then
    echo -e "${YELLOW}WARNING: Could not download updated service file. Continuing with existing.${NC}"
fi

# --- Restart service ---
echo ""
echo "Restarting service..."
systemctl daemon-reload
systemctl start lnkact-monitor

sleep 2
if systemctl is-active --quiet lnkact-monitor; then
    echo -e "${GREEN}Service is running successfully.${NC}"
    # Clean up backup on success
    rm -f "$BACKUP"
else
    echo -e "${RED}WARNING: Service did not start after update. Restoring backup...${NC}"
    cp "$BACKUP" "$SCRIPT_FILE"
    systemctl start lnkact-monitor
    echo "Check logs: journalctl -u lnkact-monitor -f"
    exit 1
fi

echo ""
echo "=============================================="
echo -e "${GREEN}Update complete!${NC}"
echo ""
echo "If new configuration options were added, they will"
echo "be appended to your conf file with default values"
echo "and logged on next service start. Review with:"
echo "  journalctl -u lnkact-monitor | grep 'NEW config'"
echo ""
echo "  journalctl -u lnkact-monitor -f"
echo "=============================================="
echo ""
