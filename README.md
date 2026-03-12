# ASL3 Link Activity Monitor

A systemd-based link activity monitor for ASL3 (AllStarLink 3) that replaces the broken native `lnkactenable`/`lnkactmacro` functionality in ASL3 3.7.1+.

## What It Does

When your repeater node has been inactive (no local RF activity or new node connections) for a configurable period, the monitor plays a warning announcement and then resets the node — disconnecting any linked nodes and reconnecting to your configured permanent hub(s).

**Activity that resets the inactivity timer:**
- Local RF activity (kerchunks) detected on your node
- A new node connecting to or from your node (requires connection logging)

**Features:**
- Configurable inactivity timeout
- TTS or pre-recorded audio warning before reset
- Skip reset if only permanent/hub nodes are connected
- Scheduled blackout windows (suppress resets during nets, etc.)
- Scheduled forced resets at configured times of day
- Reconnect to multiple nodes after reset
- Daily reset counter logged
- Asterisk availability check before each cycle
- Connection log rotation detection
- Separate config file survives script updates

## Requirements

- ASL3 on Debian 12
- `asl-tts` (included with ASL3) if using TTS warning mode
- Connection logging (optional but recommended) — see [asl3-connection-log](https://github.com/N6LKA/asl3-connection-log)

## Installation & Updates

Run this single command as root for both fresh installs and updates:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/N6LKA/asl3-link-activity-monitor/main/install.sh)
```

**Fresh install:** The installer will prompt you for your node number and basic settings, create the configuration file, and start the service.

**Existing install detected:** The installer will stop the service, back up the existing script, download the latest version, and restart. Your `lnkact-monitor.conf` is never modified. If an update adds new configuration variables, they will be automatically appended to your conf file with default values on the next service start.

> **Tip:** For initial testing, set `INACT_TIMEOUT=180` in the conf file so you can verify the warning and reset fire within a few minutes, then change it back to your desired value.

## Connection Logging (Optional)

ASL3 does not have a native connection log. To enable connection-based timer resets, install the companion logging scripts first:

👉 [https://github.com/N6LKA/asl3-connection-log](https://github.com/N6LKA/asl3-connection-log)

If you skip this, set `CONNECT_LOG=""` in the conf file. The monitor will still work using RF activity (kerchunk counter) only.

> **Important:** The connection log file must be owned by the `asterisk` user or the logging scripts will not be able to write to it. If you ever recreate or replace the file manually (e.g. during log rotation testing), restore ownership with:
> ```bash
> chown asterisk:asterisk /var/log/asterisk/connectlog
> chmod 644 /var/log/asterisk/connectlog
> ```

## Configuration

All settings are in `/etc/asterisk/scripts/lnkact-monitor.conf`. After making changes, restart the service:

```bash
systemctl restart lnkact-monitor
```

### Configuration Reference

| Variable | Default | Description |
|---|---|---|
| `NODE` | *(required)* | Your ASL3 node number |
| `INACT_TIMEOUT` | `3600` | Seconds of inactivity before reset (3600 = 60 min) |
| `POLL_INTERVAL` | `2` | How often to check activity (seconds) |
| `WARN_MODE` | `tts` | Warning mode: `tts`, `file`, or `none` |
| `WARN_TTS_TEXT` | *see conf* | TTS text spoken as warning |
| `WARN_AUDIO` | *see conf* | Path to pre-recorded warning file (no extension) |
| `WARN_LEAD` | `30` | Seconds before reset to play warning |
| `WARN_OFFSET_TTS` | `7` | Extra seconds for TTS processing time |
| `WARN_OFFSET_FILE` | `7` | Extra seconds for file playback time |
| `CONNECT_LOG` | `/var/log/asterisk/connectlog` | Path to connection log, or blank to disable |
| `PERMANENT_NODES` | *(blank)* | Space-separated hub/permanent nodes — reset skipped if only these connected |
| `BLACKOUT_START` | *(blank)* | Blackout window start `HH:MM` 24hr — resets suppressed |
| `BLACKOUT_END` | *(blank)* | Blackout window end `HH:MM` 24hr |
| `SCHEDULED_RESETS` | *(blank)* | Space-separated `HH:MM` times to force a daily reset |
| `USE_TELEMETRY` | `yes` | Wrap reset in telemetry off/on (cop 34/35) |
| `DISCONNECT_ALL` | `yes` | Disconnect all nodes before reconnecting |
| `RECONNECT_NODES` | *(blank)* | Space-separated nodes to reconnect after reset |
| `ANNOUNCE` | `yes` | Play TTS announcement after reset |
| `ANNOUNCE_TEXT` | `Connection Reset` | TTS text spoken after reset |

### Blackout Window Example

Suppress resets during your Monday night net (7 PM – 9 PM):

```
BLACKOUT_START="19:00"
BLACKOUT_END="21:00"
```

Midnight-spanning windows are supported (e.g. `22:00` to `06:00`).

### Scheduled Reset Example

Force a reset every morning at 6 AM and every evening at 4 PM:

```
SCHEDULED_RESETS="06:00 16:00"
```

Scheduled resets always fire regardless of activity or connected nodes. The configured warning plays first.

## Service Commands

```bash
systemctl start lnkact-monitor
systemctl stop lnkact-monitor
systemctl restart lnkact-monitor
systemctl status lnkact-monitor
journalctl -u lnkact-monitor -f
```

## Files

| File | Location | Description |
|---|---|---|
| `lnkact-monitor.sh` | `/etc/asterisk/scripts/` | Main script (do not edit) |
| `lnkact-monitor.conf` | `/etc/asterisk/scripts/` | User configuration |
| `lnkact-monitor.service` | `/etc/systemd/system/` | Systemd service definition |

## Background

The native `lnkactenable`/`lnkactmacro` timer in ASL3 3.7.1 is broken — the timer never fires. This monitor was written as a full replacement, using the kerchunk counter from `rpt stats` for local RF detection (which only increments on local RF activity, not linked node audio) and direct link variables (`RPT_ALINKS`/`RPT_NUMALINKS`) to avoid false triggers from hub-propagated phantom nodes.

## Author

Larry K. Aycock (N6LKA)

## License

MIT License — free to use, modify, and share.