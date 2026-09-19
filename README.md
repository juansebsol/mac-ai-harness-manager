# Harness Manager

Native macOS control center for AI coding harnesses — CLIs, apps, MCP servers, skills, providers, and processes.

Not an AI coding agent itself. It sits above harnesses and manages them.

## Requirements

- macOS 14+
- Xcode 15+ (or Xcode Command Line Tools with full Xcode for SwiftUI app builds)

## Build

```bash
./Scripts/build.sh          # Release
./Scripts/build.sh Debug    # Debug
```

Output:

```text
build/Harness Manager.app
```

Open:

```bash
open "build/Harness Manager.app"
```

Or open `HarnessManager.xcodeproj` in Xcode and run the **HarnessManager** scheme.

## Architecture

| Area | Role |
|------|------|
| `Registry/` | Declarative harness definitions — add a new harness here |
| `Services/` | Discovery, package managers, processes, MCP, skills, updates, command runner |
| `Diagnostics/` | Pluggable doctor checks per harness |
| `Views/` | Native SwiftUI (NavigationSplitView, tables, sheets, menu bar) |
| `Models/` | Codable domain types |

Discovery is **local and read-only**. Mutating actions (updates, terminate) require explicit user confirmation and show the exact command.

## Initial harness support

**Complete detection:** Claude Code, Codex CLI, Gemini CLI, OpenCode, Cursor, Warp

**Incomplete placeholders:** T3 Code, Conductor, Superset, Paseo, Emdash, Hermes, Kiro, ZCode, Antigravity, OpenChamber, Vibe Kanban

## Smoke test

```bash
./Scripts/smoke-test.sh
```

This builds Release, launches the app, asserts it stays alive, confirms the main thread is idle, and checks CPU settles near 0% (guards against the SwiftUI main-menu invalidation beach-ball).
