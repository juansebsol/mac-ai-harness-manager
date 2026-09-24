export const site = {
  name: "Harness Manager",
  description: "Manage your AI stack in one native Mac app. Discover tools, MCPs, and skills, review updates, and compare models across 31 ranking collections. Free and open source.",
  repository: "https://github.com/juansebsol/mac-ai-harness-manager",
  productHuntUrl: "https://www.producthunt.com/products/harness-manager?embed=true&utm_source=badge-featured&utm_medium=badge&utm_campaign=badge-harness-manager",
  productHuntBadge: "https://api.producthunt.com/widgets/embed-image/v1/featured.svg?post_id=1259502&theme=light&t=1790233775318",
  download: process.env.NEXT_PUBLIC_DOWNLOAD_URL?.startsWith("https://") ? process.env.NEXT_PUBLIC_DOWNLOAD_URL : "/downloads/Harness-Manager.dmg",
  version: "0.1.0",
};

export const tools = [
  { id: "claude-code", name: "Claude Code" },
  { id: "codex", name: "Codex" },
  { id: "gemini-cli", name: "Gemini CLI" },
  { id: "cursor", name: "Cursor" },
  { id: "opencode", name: "OpenCode" },
  { id: "warp", name: "Warp" },
  { id: "antigravity", name: "Antigravity" },
  { id: "antigravity-ide", name: "Antigravity IDE" },
  { id: "t3-code", name: "T3 Code" },
  { id: "conductor", name: "Conductor" },
  { id: "superset", name: "Superset" },
  { id: "paseo", name: "Paseo" },
  { id: "cmux", name: "cmux" },
  { id: "orca", name: "Orca" },
  { id: "herdr", name: "Herdr" },
  { id: "emdash", name: "Emdash" },
];

export const tour = [
  { id: "workspace", label: "Your workspace", title: "The whole picture. At a glance.", description: "See what’s installed, what’s running, and what needs an update.", alt: "Harness Manager’s native workspace with installed tools, status, and update controls" },
  { id: "discover", label: "Discover", title: "Find your next favorite.", description: "Explore coding tools with clear install options and familiar faces.", alt: "Native Discover screen with tool logos and installation cards" },
  { id: "updates", label: "Updates", title: "Stay current. Stay in control.", description: "Find available updates, then review the command before it runs.", alt: "Native workspace filtered to harnesses with available updates" },
  { id: "news", label: "The briefing", title: "Keep up with what’s next.", description: "Real articles, announcements, community discoveries, and release notes.", alt: "Native harness news reader showing sourced articles and publication dates" },
];

export const slides = [
  { id: "01", name: "overview", title: "Your AI stack.\nUnder control.", description: "Manage your tools. Compare models. Keep building. Native to Mac, free and open source.", view: "workspace", label: "MEET HARNESS MANAGER" },
  { id: "02", name: "discover", title: "Build a better\nAI stack.", description: "Discover harnesses, MCPs, and skills. Find the next addition to your workflow, all in one catalog.", view: "discover", label: "EXPAND YOUR TOOLBOX" },
  { id: "03", name: "updates", title: "Less upkeep.\nMore time.", description: "Know what needs an update. Review the command. Get back to your work.", view: "updates", label: "STAY CURRENT" },
  { id: "04", name: "providers", title: "Your setup.\nIn plain sight.", description: "Providers, MCP servers, and skills. A clearer view of the pieces behind your tools.", view: "providers", label: "UNDERSTAND YOUR WORKSPACE" },
  { id: "05", name: "processes", title: "Know what’s\nrunning.", description: "See active harnesses, resource usage, and the projects they belong to.", view: "processes", label: "LIVE ON YOUR MAC" },
  { id: "06", name: "news", title: "A little ahead\nof the curve.", description: "News, new tools, and thoughtful reads. With real sources, beyond the changelog.", view: "news", label: "THE HARNESS BRIEFING" },
  { id: "07", name: "benchmarks", title: "Right model.\nRight task.", description: "31 ranking collections. Coding, design, agents, reasoning, and more. Compare the models for your next project.", view: "rankings-coding", label: "BENCHMARKS & RANKINGS" },
];

// Match the collections offered by the native Benchmarks page.
export const rankingGroups = [
  { name: "General", collections: ["Smartest", "Coding", "Agents", "Fastest", "Low latency", "Cheapest", "Free"] },
  { name: "Development", collections: ["Design", "UI components", "Full-stack apps", "Mobile apps", "Tool calling", "Long-context reasoning"] },
  { name: "Reasoning & knowledge", collections: ["Reasoning", "Math", "Science", "Writing", "Instruction following", "RAG", "SQL and analysis"] },
  { name: "Deployment", collections: ["Local", "Open-source", "Small and fast", "Long context", "Vision", "Uncensored"] },
  { name: "Creative & specialist", collections: ["Data visualization", "SVG", "Game development", "3D", "Roleplay"] },
];
