#!/bin/zsh
# Kiest de simulator voor build.sh en test.sh: FOODY_SIMULATOR als die gezet is, anders iPhone 17,
# anders de eerste beschikbare iPhone. Print de naam; faalt als er geen iPhone-simulator is.
set -e
if [[ -n "${FOODY_SIMULATOR:-}" ]]; then
  echo "$FOODY_SIMULATOR"; exit 0
fi
available="$(xcrun simctl list devices available 2>/dev/null | grep -oE 'iPhone[^(]*' | sed 's/ *$//' | sort -u)"
if echo "$available" | grep -qx 'iPhone 17'; then
  echo "iPhone 17"
elif [[ -n "$available" ]]; then
  echo "$available" | head -1
else
  echo "Geen iPhone-simulator gevonden. Installeer een iOS-runtime via Xcode > Settings > Components." >&2
  exit 1
fi
