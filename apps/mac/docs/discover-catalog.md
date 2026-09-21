# Discover catalog

Discover has three categories: Harnesses, MCPs, and Skills. The sidebar's MCP Servers and Skills pages still describe local configuration; Discover browses projects to explore.

## Data and ranking

- Supported harnesses and meta harnesses retain their existing installation controls and curated popularity order, grouped in the Harnesses tab.
- Additional harness projects, MCP projects, and skills are discovered from public GitHub repository search, ordered by descending star count. Stars measure repository interest, not installs, compatibility, or quality.
- Queries use `coding-agent` and `agentic-ide` topics for harnesses, `mcp-server` with MCP in the repository name for MCPs, and `agent-skills` and `claude-skills` for skills. Search results exclude forks and archived repositories, require over 100 stars, and retrieve up to 40 results per query.
- The ten user-selected skill repositories remain in the collection even when they lack topic tags. Their names and descriptions are curated; star counts come from GitHub. Five MCP starters and seven known harness repositories are also included.
- Duplicate repositories are merged case-insensitively. Archived discovered entries are removed; archived selected entries remain labeled and sort last. Up to 80 discovered entries plus selected starters are retained per category.
- Public topic search is not an exhaustive registry. MCP results can include frameworks and learning resources; skill results can include toolkits and collections. Generic results are labeled as projects rather than claiming a uniform installation format.

## Refresh and offline behavior

Opening a category loads its cached collection immediately and refreshes if the last complete refresh is older than 24 hours. Refresh can be requested manually, with a one-minute attempt throttle. GitHub's unauthenticated rate limits apply. Partial failures preserve earlier results and show a retry notice; a partial response does not mark the category fully refreshed. Navigation cancellation preserves the existing cache.

Cache: `~/Library/Caches/HarnessManager/discover-v1.json`. First launch offline shows bundled starter entries with unavailable star counts. Repository owner avatars load asynchronously with category-symbol fallbacks.

## Setup links

The new repository cards open the corresponding GitHub project for documentation and installation instructions. They do not execute commands, install skills, write MCP configuration, or request account credentials. Supported harness Install actions remain unchanged.

## Verification

`bash apps/mac/scripts/test-workflows.sh` covers ranking, deduplication, selected-entry preservation, offline merging, URL validation, response decoding, and corrupt-cache fallback in addition to existing workflow tests. `DiscoverCatalogTests.swift --live` can be compiled as a standalone probe to verify network responses. Live requests and category navigation, Skills search, descending star counts, and the rendered MCP grid were checked on September 20, 2026.

Reference: https://docs.github.com/en/rest/search/search#search-repositories
