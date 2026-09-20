import Foundation

enum ClaudeCodeDefinition {
    static let definition = HarnessDefinition(
        id: "claude-code",
        name: "Claude Code",
        binaryNames: ["claude"],
        applicationBundleIdentifiers: [],
        configPaths: [
            ConfigPathSpec(path: "~/.claude", label: "Config directory", kind: .directory),
            ConfigPathSpec(path: "~/.claude/settings.json", label: "Settings", kind: .file),
            ConfigPathSpec(path: "~/.claude.json", label: "Root settings", kind: .file),
            ConfigPathSpec(path: "~/.claude/mcp.json", label: "MCP config", kind: .file),
            ConfigPathSpec(path: "~/.claude/skills", label: "Skills", kind: .directory)
        ],
        versionArguments: ["--version"],
        installationMethods: [
            .npm(package: "@anthropic-ai/claude-code"),
            .pnpm(package: "@anthropic-ai/claude-code"),
            .bun(package: "@anthropic-ai/claude-code"),
            .homebrew(formula: "claude-code"),
            .standalone
        ],
        providerIds: ["anthropic"],
        website: URL(string: "https://docs.anthropic.com/en/docs/claude-code"),
        iconName: "terminal",
        isComplete: true
    )
}

enum CodexDefinition {
    static let definition = HarnessDefinition(
        id: "codex",
        name: "OpenAI Codex CLI",
        binaryNames: ["codex"],
        applicationBundleIdentifiers: [],
        configPaths: [
            ConfigPathSpec(path: "~/.codex", label: "Config directory", kind: .directory),
            ConfigPathSpec(path: "~/.codex/config.toml", label: "Config", kind: .file),
            ConfigPathSpec(path: "~/.codex/auth.json", label: "Auth", kind: .file)
        ],
        versionArguments: ["--version"],
        installationMethods: [
            .npm(package: "@openai/codex"),
            .pnpm(package: "@openai/codex"),
            .bun(package: "@openai/codex"),
            .homebrew(formula: "codex"),
            .standalone
        ],
        providerIds: ["openai"],
        website: URL(string: "https://github.com/openai/codex"),
        iconName: "terminal.fill",
        isComplete: true
    )
}

enum GeminiCLIDefinition {
    static let definition = HarnessDefinition(
        id: "gemini-cli",
        name: "Gemini CLI",
        binaryNames: ["gemini"],
        applicationBundleIdentifiers: [],
        configPaths: [
            ConfigPathSpec(path: "~/.gemini", label: "Config directory", kind: .directory),
            ConfigPathSpec(path: "~/.config/gemini", label: "Config directory", kind: .directory)
        ],
        versionArguments: ["--version"],
        installationMethods: [
            .npm(package: "@google/gemini-cli"),
            .pnpm(package: "@google/gemini-cli"),
            .bun(package: "@google/gemini-cli"),
            .homebrew(formula: "gemini-cli"),
            .standalone
        ],
        providerIds: ["google"],
        website: URL(string: "https://github.com/google-gemini/gemini-cli"),
        iconName: "sparkles",
        isComplete: true
    )
}

enum OpenCodeDefinition {
    static let definition = HarnessDefinition(
        id: "opencode",
        name: "OpenCode",
        binaryNames: ["opencode"],
        applicationBundleIdentifiers: [],
        configPaths: [
            ConfigPathSpec(path: "~/.config/opencode", label: "Config directory", kind: .directory),
            ConfigPathSpec(path: "~/.opencode", label: "Config directory", kind: .directory)
        ],
        versionArguments: ["--version"],
        installationMethods: [
            .homebrew(formula: "opencode"),
            .npm(package: "opencode-ai"),
            .pnpm(package: "opencode-ai"),
            .bun(package: "opencode-ai"),
            .standalone
        ],
        providerIds: ["openrouter", "openai", "anthropic"],
        website: URL(string: "https://opencode.ai"),
        iconName: "chevron.left.forwardslash.chevron.right",
        isComplete: true
    )
}

enum CursorDefinition {
    static let definition = HarnessDefinition(
        id: "cursor",
        name: "Cursor",
        binaryNames: ["cursor", "cursor-agent"],
        applicationBundleIdentifiers: ["com.todesktop.230313mzl4w4u92"],
        configPaths: [
            ConfigPathSpec(path: "~/Library/Application Support/Cursor", label: "Application Support", kind: .directory),
            ConfigPathSpec(path: "~/.cursor", label: "Config directory", kind: .directory),
            ConfigPathSpec(path: "~/.cursor/mcp.json", label: "MCP config", kind: .file),
            ConfigPathSpec(path: "~/.cursor/skills", label: "Skills", kind: .directory)
        ],
        versionArguments: ["--version"],
        installationMethods: [
            .homebrew(formula: "cursor"),
            .macApplication,
            .standalone
        ],
        providerIds: [],
        website: URL(string: "https://cursor.com"),
        iconName: "macwindow",
        isComplete: true
    )
}

enum WarpDefinition {
    static let definition = HarnessDefinition(
        id: "warp",
        name: "Warp",
        binaryNames: ["warp", "warp-cli"],
        applicationBundleIdentifiers: ["dev.warp.Warp-Stable", "dev.warp.Warp"],
        configPaths: [
            ConfigPathSpec(path: "~/.warp", label: "Config directory", kind: .directory),
            ConfigPathSpec(path: "~/Library/Application Support/dev.warp.Warp-Stable", label: "Application Support", kind: .directory)
        ],
        versionArguments: ["--version"],
        installationMethods: [
            .macApplication,
            .homebrew(formula: "warp"),
            .standalone
        ],
        providerIds: [],
        website: URL(string: "https://www.warp.dev"),
        iconName: "rectangle.and.terminal",
        isComplete: true
    )
}

/// IDE metadata verified against Homebrew's antigravity-ide cask.
enum AntigravityIDEDefinition {
    static let definition = HarnessDefinition(
        id: "antigravity-ide",
        name: "Antigravity IDE",
        binaryNames: ["antigravity-ide", "agy-ide"],
        applicationBundleIdentifiers: ["com.google.antigravity-ide"],
        configPaths: [
            ConfigPathSpec(path: "~/Library/Application Support/Antigravity IDE", label: "Application Support", kind: .directory),
            ConfigPathSpec(path: "~/.antigravity-ide", label: "Config directory", kind: .directory),
            ConfigPathSpec(path: "~/.gemini/antigravity-ide", label: "Agent config directory", kind: .directory)
        ],
        versionArguments: ["--version"],
        installationMethods: [.homebrew(formula: "antigravity-ide"), .macApplication],
        providerIds: ["google"],
        website: URL(string: "https://antigravity.google/product/antigravity-ide"),
        iconName: "macwindow",
        isComplete: true
    )
}

/// The standalone orchestration app is distinct from Antigravity IDE.
enum AntigravityDefinition {
    static let definition = HarnessDefinition(
        id: "antigravity",
        name: "Antigravity",
        binaryNames: [],
        applicationBundleIdentifiers: ["com.google.antigravity"],
        configPaths: [
            ConfigPathSpec(path: "~/Library/Application Support/Antigravity", label: "Application Support", kind: .directory),
            ConfigPathSpec(path: "~/.antigravity", label: "Config directory", kind: .directory),
            ConfigPathSpec(path: "~/.gemini/antigravity", label: "Agent config directory", kind: .directory)
        ],
        versionArguments: [],
        installationMethods: [.homebrew(formula: "antigravity"), .macApplication],
        providerIds: ["google"],
        website: URL(string: "https://antigravity.google/product/antigravity-2"),
        iconName: "macwindow",
        isComplete: true
    )
}

// Verified install sources are documented in docs/meta-harness-catalog.md.
enum MetaHarnessDefinitions {
    static let t3_code = HarnessDefinition(
        id: "t3-code", name: "T3 Code",
        binaryNames: [], applicationBundleIdentifiers: ["com.t3tools.t3code"],
        installationMethods: [.homebrew(formula: "homebrew/cask/t3-code"), .macApplication],
        website: URL(string: "https://t3.codes/"), iconName: "square.stack.3d.up",
        isComplete: true, notes: "A desktop control plane for coding agents, conversations, and code review."
    )
    static let conductor = HarnessDefinition(
        id: "conductor", name: "Conductor",
        binaryNames: [], applicationBundleIdentifiers: ["com.conductor.app"],
        installationMethods: [.homebrew(formula: "homebrew/cask/conductor"), .macApplication],
        website: URL(string: "https://conductor.build/"), iconName: "square.stack.3d.up",
        isComplete: true, notes: "Run coding agents in parallel with separate project workspaces."
    )
    static let superset = HarnessDefinition(
        id: "superset", name: "Superset",
        binaryNames: [], applicationBundleIdentifiers: ["com.superset.desktop"],
        installationMethods: [.homebrew(formula: "homebrew/cask/superset"), .macApplication],
        website: URL(string: "https://superset.sh/"), iconName: "square.stack.3d.up",
        isComplete: true, notes: "Organize coding agents, terminals, and worktrees in one workspace."
    )
    static let paseo = HarnessDefinition(
        id: "paseo", name: "Paseo",
        binaryNames: ["paseo"], applicationBundleIdentifiers: ["sh.paseo.desktop"],
        installationMethods: [.homebrew(formula: "homebrew/cask/paseo"), .macApplication],
        website: URL(string: "https://paseo.sh/"), iconName: "square.stack.3d.up",
        isComplete: true, notes: "Control self-hosted coding agents from your desktop, phone, or browser."
    )
    static let cmux = HarnessDefinition(
        id: "cmux", name: "cmux",
        binaryNames: ["cmux"], applicationBundleIdentifiers: ["ai.manaflow.cmuxterm"],
        installationMethods: [.homebrew(formula: "manaflow-ai/cmux/cmux"), .macApplication],
        website: URL(string: "https://cmux.com/"), iconName: "square.stack.3d.up",
        isComplete: true, notes: "A native terminal with vertical tabs and notifications for coding agents."
    )
    static let orca = HarnessDefinition(
        id: "orca", name: "Orca",
        binaryNames: ["orca"], applicationBundleIdentifiers: ["com.stablyai.orca"],
        installationMethods: [.homebrew(formula: "stablyai/orca/orca"), .macApplication],
        website: URL(string: "https://onorca.dev/"), iconName: "square.stack.3d.up",
        isComplete: true, notes: "Stably’s agent workspace for parallel terminals, worktrees, and review."
    )
    static let herdr = HarnessDefinition(
        id: "herdr", name: "Herdr",
        binaryNames: ["herdr"], applicationBundleIdentifiers: [],
        installationMethods: [.homebrew(formula: "herdr")],
        website: URL(string: "https://herdr.dev/"), iconName: "square.stack.3d.up",
        isComplete: true, notes: "A terminal multiplexer with workspaces and live coding-agent status."
    )
    static let emdash = HarnessDefinition(
        id: "emdash", name: "Emdash",
        binaryNames: [], applicationBundleIdentifiers: ["com.emdash.stable", "com.emdash"],
        installationMethods: [.homebrew(formula: "homebrew/cask/emdash"), .macApplication],
        website: URL(string: "https://emdash.com/"), iconName: "square.stack.3d.up",
        isComplete: true, notes: "Run coding agents in parallel with isolated Git worktrees."
    )
}
