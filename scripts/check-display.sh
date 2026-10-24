#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/checks .build/clang-cache
swiftc -module-cache-path "$PWD/.build/clang-cache" \
  Sources/FlowScroll/DisplayClock.swift Tests/FlowScrollTests/DisplayClockCheck.swift \
  -o .build/checks/DisplayClockCheck
.build/checks/DisplayClockCheck
