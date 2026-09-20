#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc -module-cache-path "$TEST_DIR/module-cache" -parse-as-library HarnessManager/Models/*.swift HarnessManager/Registry/*.swift HarnessManager/Registry/Definitions/*.swift HarnessManager/Services/CommandRunner.swift HarnessManager/Services/DiscoveryCache.swift HarnessManager/Services/UpdateCheckService.swift Tests/CommandWorkflowTests.swift -o "$TEST_DIR/workflow-tests"
"$TEST_DIR/workflow-tests"
