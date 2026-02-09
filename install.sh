#!/usr/bin/env bash
set -euo pipefail

DEST_BIN="/usr/local/bin/keycard"
DEST_CFG="/etc/keycard.yml"

echo "Installing keycard to $DEST_BIN ..."
sudo install -m 0755 bin/keycard "$DEST_BIN"

if [[ ! -f "$DEST_CFG" ]]; then
  echo "No config found at $DEST_CFG. Installing example config..."
  sudo install -m 0644 examples/keycard.yml "$DEST_CFG"
else
  echo "Config already exists at $DEST_CFG (leaving as-is)."
fi

echo "Checking dependencies ..."

if ! command -v yq >/dev/null 2>&1; then
  echo ""
  echo "⚠️  Missing yq (Mike Farah's Go version)."
  echo "   See: https://github.com/mikefarah/yq#install"
  echo ""
elif ! yq --version 2>&1 | grep -qi 'mikefarah'; then
  echo ""
  echo "⚠️  Found yq, but it doesn't appear to be Mike Farah's Go version."
  echo "   keycard requires: https://github.com/mikefarah/yq"
  echo ""
fi

if ! command -v setfacl >/dev/null 2>&1 || ! command -v getfacl >/dev/null 2>&1; then
  echo "⚠️  Missing setfacl/getfacl. Install with: sudo apt-get install -y acl"
fi

echo ""
echo "Done."
echo "Try: keycard doctor        (no sudo needed)"
echo "     sudo keycard list"
