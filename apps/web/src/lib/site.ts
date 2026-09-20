export const site = {
  name: "Harness Manager",
  description: "Your AI coding tools, together in one native Mac app. Discover harnesses, review updates, and keep up with what’s next. Free and open source.",
  repository: "https://github.com/juansebsol/mac-ai-harness-manager",
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
];

export const tour = [
  { id: "workspace", label: "Your workspace", title: "The whole picture. At a glance.", description: "See what’s installed, what’s running, and what needs an update.", alt: "Harness Manager’s native workspace with installed tools, status, and update controls" },
  { id: "discover", label: "Discover", title: "Find your next favorite.", description: "Explore coding tools with clear install options and familiar faces.", alt: "Native Discover screen with tool logos and installation cards" },
  { id: "updates", label: "Updates", title: "Stay current. Stay in control.", description: "Find available updates, then review the command before it runs.", alt: "Native workspace filtered to harnesses with available updates" },
  { id: "news", label: "The briefing", title: "Keep up with what’s next.", description: "Real articles, announcements, community discoveries, and release notes.", alt: "Native harness news reader showing sourced articles and publication dates" },
];

export const slides = [
  { id: "01", name: "overview", title: "Your AI tools.\nFinally, together.", description: "A native home for your coding harnesses. Free and open source.", view: "workspace", label: "MEET HARNESS MANAGER" },
  { id: "02", name: "discover", title: "A new favorite\nis out there.", description: "Explore the tools shaping how we code. Install with a clear view of what happens next.", view: "discover", label: "EXPAND YOUR TOOLBOX" },
  { id: "03", name: "updates", title: "Less upkeep.\nMore time.", description: "Know what needs an update. Review the command. Get back to your work.", view: "updates", label: "STAY CURRENT" },
  { id: "04", name: "providers", title: "Your setup.\nIn plain sight.", description: "Providers, MCP servers, and skills. A clearer view of the pieces behind your tools.", view: "providers", label: "UNDERSTAND YOUR WORKSPACE" },
  { id: "05", name: "processes", title: "Know what’s\nrunning.", description: "See active harnesses, resource usage, and the projects they belong to.", view: "processes", label: "LIVE ON YOUR MAC" },
  { id: "06", name: "news", title: "A little ahead\nof the curve.", description: "News, new tools, and thoughtful reads. With real sources, beyond the changelog.", view: "news", label: "THE HARNESS BRIEFING" },
];
