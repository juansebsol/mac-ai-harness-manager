import Foundation

struct ProviderDefinition: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let environmentVariables: [String]
    let configHints: [String]
}

struct ProviderStatus: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    var isConfigured: Bool
    var detectedSignals: [String]
    var harnessIds: [String]

    var configurationLabel: String {
        isConfigured ? "Configured" : "Not detected"
    }
}

enum ProviderCatalog {
    static let all: [ProviderDefinition] = [
        .init(id: "openai", name: "OpenAI", environmentVariables: ["OPENAI_API_KEY"], configHints: ["~/.openai", "~/.config/openai"]),
        .init(id: "anthropic", name: "Anthropic", environmentVariables: ["ANTHROPIC_API_KEY", "CLAUDE_API_KEY"], configHints: ["~/.claude", "~/.config/claude"]),
        .init(id: "google", name: "Google Gemini", environmentVariables: ["GOOGLE_API_KEY", "GEMINI_API_KEY", "GOOGLE_GENERATIVE_AI_API_KEY"], configHints: ["~/.gemini", "~/.config/gemini"]),
        .init(id: "openrouter", name: "OpenRouter", environmentVariables: ["OPENROUTER_API_KEY"], configHints: ["~/.config/openrouter"]),
        .init(id: "zai", name: "Z.ai", environmentVariables: ["ZAI_API_KEY", "Z_AI_API_KEY"], configHints: []),
        .init(id: "minimax", name: "MiniMax", environmentVariables: ["MINIMAX_API_KEY"], configHints: []),
        .init(id: "groq", name: "Groq", environmentVariables: ["GROQ_API_KEY"], configHints: []),
        .init(id: "xai", name: "xAI", environmentVariables: ["XAI_API_KEY", "GROK_API_KEY"], configHints: []),
        .init(id: "mistral", name: "Mistral", environmentVariables: ["MISTRAL_API_KEY"], configHints: [])
    ]

    static func displayName(for id: String) -> String {
        all.first(where: { $0.id == id })?.name ?? id.capitalized
    }

    static func definition(for id: String) -> ProviderDefinition? {
        all.first(where: { $0.id == id })
    }
}
