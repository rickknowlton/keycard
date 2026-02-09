#!/usr/bin/env bash
set -euo pipefail

echo "Stopping any active keycard timers..."
sudo systemctl list-timers --all --no-pager | awk '/keycard-.*\.timer/ {print $1}' | while read -r t; do
  sudo systemctl stop "$t" || true
done

echo "Removing binary..."
sudo rm -f /usr/local/bin/keycard

echo "Config left in place: /etc/keycard.yml (remove manually if desired)"
echo "Done."
