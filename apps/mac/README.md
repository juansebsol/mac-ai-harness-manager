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

**Complete detection:** Claude Code, Codex CLI, Gemini CLI, OpenCode, Cursor, Warp, Antigravity, Antigravity IDE, T3 Code, Conductor, Superset, Paseo, cmux, Orca, Herdr, Emdash

**Incomplete placeholders:** Hermes, Kiro, ZCode, OpenChamber, Vibe Kanban

## Smoke test

```bash
./Scripts/smoke-test.sh
```

This builds Release, launches the app, asserts it stays alive, confirms the main thread is idle, and checks CPU settles near 0% (guards against the SwiftUI main-menu invalidation beach-ball).

## Workspace and release feeds

Discover prioritizes supported tools; enable “Include tools with limited support” to see incomplete catalog entries. Harness news fetches stable releases from the official Claude Code, Codex, and Gemini CLI GitHub repositories, with search, source filters, and retry feedback. GitHub rate limits and network failures are shown inline.

Install/update commands use the discovered PATH. Supported npm tools can use npm, pnpm, or Bun; Homebrew inventory includes casks. Native Claude Code supports `claude update`. Apps installed outside a supported package manager use their own updater or vendor website. Harness Manager itself does not yet have a signed self-update distribution service.

Run `./Scripts/test-workflows.sh` for isolated command workflow checks. These use temporary fake package managers and do not install or update real tools.

## Benchmarks

The Benchmarks sidebar page shows Modelgrep rankings with native charts, model search, source links, pricing, and capability metrics. Each view fetches up to 200 models. Scores refresh on opening after one hour or manually, with an offline cache and explicit errors. See [benchmark data and refresh behavior](docs/benchmarks.md).
