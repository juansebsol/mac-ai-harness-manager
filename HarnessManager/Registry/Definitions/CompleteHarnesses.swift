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
