#!/bin/zsh
# Draait de unit tests (FoodyTests) op de iPhone-simulator. UI-tests blijven buiten beschouwing.
# Exit-code 0 alleen als alle tests slagen.
set -e
cd "$(dirname "$0")/.."
SIM="$(scripts/simulator.sh)"
LOG="$(mktemp -t foody-test)"
echo "test: FoodyTests op '$SIM'"
set +e
xcodebuild -scheme Foody -destination "platform=iOS Simulator,name=$SIM" -only-testing:FoodyTests -quiet test >"$LOG" 2>&1
rc=$?
set -e
grep -E "Test (Suite|Case|run).*(passed|failed)|✔ Test run|✘|error:|Executed [0-9]+ tests" "$LOG" | tail -15
if [[ $rc -ne 0 ]]; then
  echo "TESTS MISLUKT (exit $rc); volledige log: $LOG"
  exit $rc
fi
echo "TESTS OK"
