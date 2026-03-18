#!/usr/bin/env bash
set -euo pipefail

echo "Stopping any active keycard timers..."
sudo systemctl list-units --all --no-pager --plain --no-legend 'keycard-*.timer' \
  | awk '{print $1}' | while read -r t; do
  [[ -n "$t" ]] || continue
  sudo systemctl stop "$t" || true
  sudo systemctl reset-failed "$t" || true
done

echo "Removing binary..."
sudo rm -f /usr/local/bin/keycard

echo "Config left in place: /etc/keycard.yml (remove manually if desired)"
echo "Done."
