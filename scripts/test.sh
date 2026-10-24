#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/checks .build/clang-cache
swiftc -module-cache-path "$PWD/.build/clang-cache" \
  Sources/FlowScroll/ScrollMotion.swift Sources/FlowScroll/ScrollInput.swift Sources/FlowScroll/WheelAcceleration.swift Sources/FlowScroll/ScrollContext.swift Tests/FlowScrollTests/ScrollMotionTests.swift \
  -o .build/checks/ScrollMotionTests
.build/checks/ScrollMotionTests
