#!/bin/bash
# Clear stuck test runners (not Xcode.app) and run ReportTests.
set -euo pipefail
cd "/Volumes/SSD_CESAR/Developer/Diario da Cefaleia"
OUT=".tmp_reporttests_result.txt"

{
  echo "=== clear $(date) ==="
  for name in xcodebuild xctest; do
    pgrep -x "$name" | while read -r pid; do
      echo "killing $name pid=$pid"
      kill -9 "$pid" 2>/dev/null || true
    done
  done
  ps aux | grep -E '[X]CTest|[x]ctestrunner|[T]estRunner' | awk '{print $2}' | while read -r pid; do
    echo "killing helper pid=$pid"
    kill -9 "$pid" 2>/dev/null || true
  done

  SIM="iPhone 16"
  if ! xcrun simctl list devices available | grep -q "$SIM"; then
    SIM=$(xcrun simctl list devices available | grep -i 'iPhone' | tail -1 | sed -E 's/^[[:space:]]*([^(]+).*/\1/' | sed 's/[[:space:]]*$//')
  fi
  echo "SIM=$SIM"

  echo "=== xcodebuild test ==="
  xcodebuild test \
    -scheme "Diario da Cefaleia" \
    -destination "platform=iOS Simulator,name=$SIM" \
    -only-testing:"Diario da Cefaleia Tests/ReportTests" \
    2>&1 | tee /tmp/reporttests_xcodebuild.log | tail -120
} | tee "$OUT"

echo "Wrote $OUT"
