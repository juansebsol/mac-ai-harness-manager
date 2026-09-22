#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc -module-cache-path "$TEST_DIR/module-cache" -parse-as-library HarnessManager/Models/*.swift HarnessManager/Registry/*.swift HarnessManager/Registry/Definitions/*.swift HarnessManager/Services/CommandRunner.swift HarnessManager/Services/DiscoveryCache.swift HarnessManager/Services/UpdateCheckService.swift Tests/CommandWorkflowTests.swift -o "$TEST_DIR/workflow-tests"
"$TEST_DIR/workflow-tests"

swiftc -module-cache-path "$TEST_DIR/module-cache" -parse-as-library HarnessManager/Services/HarnessNewsService.swift Tests/NewsFeedTests.swift -o "$TEST_DIR/news-tests"
"$TEST_DIR/news-tests"

swiftc -module-cache-path "$TEST_DIR/module-cache" -parse-as-library HarnessManager/Services/DiscoverCatalogService.swift Tests/DiscoverCatalogTests.swift -o "$TEST_DIR/catalog-tests"
"$TEST_DIR/catalog-tests"

swiftc -module-cache-path "$TEST_DIR/module-cache" -parse-as-library HarnessManager/Services/BenchmarkService.swift Tests/BenchmarkTests.swift -o "$TEST_DIR/benchmark-tests"
"$TEST_DIR/benchmark-tests"

swiftc -module-cache-path "$TEST_DIR/module-cache" -parse-as-library HarnessManager/Models/CommandResult.swift HarnessManager/Services/CommandRunner.swift HarnessManager/Services/PathEnvironmentService.swift HarnessManager/Services/UsageService.swift HarnessManager/Services/DesktopUsageService.swift Tests/UsageTests.swift -o "$TEST_DIR/usage-tests"
"$TEST_DIR/usage-tests"
