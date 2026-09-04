#!/bin/zsh
# Bouwt het Foody-schema voor de iPhone-simulator. Exit-code 0 alleen bij een geslaagde build.
# Gebruik: scripts/build.sh            (stil, alleen de relevante regels bij een fout)
#          VERBOSE=1 scripts/build.sh  (volledige xcodebuild-uitvoer)
set -e
cd "$(dirname "$0")/.."
SIM="$(scripts/simulator.sh)"
LOG="$(mktemp -t foody-build)"
echo "build: Foody op '$SIM'"
set +e
if [[ -n "${VERBOSE:-}" ]]; then
  xcodebuild -scheme Foody -destination "platform=iOS Simulator,name=$SIM" build 2>&1 | tee "$LOG"
  rc=${pipestatus[1]}
else
  xcodebuild -scheme Foody -destination "platform=iOS Simulator,name=$SIM" -quiet build >"$LOG" 2>&1
  rc=$?
fi
set -e
if [[ $rc -ne 0 ]]; then
  echo "BUILD MISLUKT (exit $rc). Relevante regels:"
  grep -E "error:|warning:|BUILD|failed" "$LOG" | tail -20
  echo "volledige log: $LOG"
  exit $rc
fi
warnings=$(grep -c "warning:" "$LOG" 2>/dev/null || true)
echo "BUILD OK (${warnings:-0} warnings)"
