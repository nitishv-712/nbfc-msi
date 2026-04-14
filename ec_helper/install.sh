#!/bin/bash
# Run once to install ec_helper with setuid root
set -e
BINARY="$(dirname "$0")/ec_helper"
if [ ! -f "$BINARY" ]; then
  echo "Building ec_helper..."
  gcc -O2 -o "$BINARY" "$(dirname "$0")/ec_helper.c"
fi
echo "Installing to /usr/local/bin/ec_helper (requires sudo)..."
sudo install -o root -m 4755 "$BINARY" /usr/local/bin/ec_helper
echo "Done. ec_helper installed with setuid root."
