# Usage connections

The native app's Usage page keeps subscription limits and API spending separate. It does not add percentages from different providers or interpret missing values as zero.

## Codex

Uses an installed `codex` executable, falling back to the executable bundled with Codex or ChatGPT in `/Applications`. A short-lived `codex app-server` process uses the existing Codex account and the official stdio handshake. It reads only `account/rateLimits/read` and `account/usage/read`; it never starts a conversation or model request.

- Shows all returned limit buckets, usage and remaining percentages, window lengths, and reset times.
- Prefers `rateLimitsByLimitId` over the legacy single-bucket response.
- Shows account lifetime tokens when available. These are distinct from subscription allowance.
- API-key-only accounts and older CLI versions may not support these endpoints. Missing values are labeled unavailable.
- Stops the child process after reading, including timeout and error paths. Does not read credentials or conversation logs itself.

Protocol: https://developers.openai.com/codex/app-server

## OpenRouter

Connect an existing API key in the Usage page. The app validates it with `GET https://openrouter.ai/api/v1/key`, then stores it in macOS Keychain. A separate `GET https://openrouter.ai/api/v1/credits` fetches account totals. These requests run independently, so a forbidden credits response does not hide key spending. Requests use ephemeral sessions with no cookie or response storage; redirects are rejected. Keys are never placed in settings files, command arguments, or logs.

The large account balance is `total_credits - total_usage`, both returned by `/credits`. Both fields must be present and valid; missing data never becomes zero. Total credits and account lifetime spend are shown alongside it. A negative account balance is preserved. This calculation never uses the key budget or key lifetime spending.

OpenRouter documents `/credits` as requiring a management key. The app first tries the existing key. If access is denied, **Connect balance** accepts and validates a separate management key, stored in Keychain under `openrouter-credits`. The usage key remains under `openrouter`. A management key is used only for the read-only credits request. Balance reflects the account associated with that key. The two connections can be replaced or disconnected separately.

- Shows reported daily, monthly, and lifetime spending, in USD.
- Shows `limit_remaining` directly; does not subtract lifetime spend from a recurring budget.
- A missing limit means no key budget cap, not unlimited account credits.
- Key metrics cover only the connected key. They are labeled separately from account balance and account lifetime spend.

API: https://openrouter.ai/docs/api/api-reference/api-keys/get-current-api-key

Credits API: https://openrouter.ai/docs/api/api-reference/credits/get-remaining-credits

## Customize Usage

The page's **Customize** button opens persistent switches for each live connection and dashboard shortcut. Choices are saved to `usage.disabledProviders` in app preferences. Disabled providers are hidden, their in-flight task is cancelled, and they are excluded from subsequent refreshes. A Codex subprocess already running can finish its bounded read, but its cancelled result is discarded. Re-enabling a live provider requests fresh data. Switching visibility does not erase its credentials.

The settings list each provider integration, including Groq. Mistral currently reports only spending-limit status. Unavailable metrics are never simulated. Google Gemini API uses the bundled Gemini logo in both the page and Customize. Test fixtures exist only in the test target; the Usage page has no mock-data fallback.

Groq connects through an embedded console sign-in using a dedicated persistent WebKit data store. Its console session JWT authenticates the organization activity request; normal inference keys do not. Only the organization ID is saved in preferences. The console SDK renews its own session when possible; expiry requires reconnecting, without opening background login prompts. Disconnect clears this dedicated browser store.

Background Keychain access is silent for both modern and legacy login keychains. Native Security calls are serialized and scoped with `SecKeychainSetUserInteractionAllowed(false)` plus `LAContext.interactionNotAllowed`; the legacy flag is needed because modern query flags alone can still prompt for file-based login keychains. The previous setting is restored after each operation; item access controls are never changed. Reads run off the UI thread with a bounded wait.

OpenRouter and Antigravity credential results (including missing or denied reads) are cached in memory for the app session, so five-minute polling never retries authorization. Explicit connection replaces the cached result; disconnect clears it. Antigravity’s **Reconnect Antigravity** button alone may invoke the interactive OpenUsage Keychain reader. Ordinary Refresh, navigation, and automatic polling never invoke it. OpenRouter’s explicit connection/disconnection actions can authorize a Keychain write. Manually entered provider keys remain in Keychain; Antigravity’s derived, expiring access token uses the restricted file cache described below.

Development builds remain ad-hoc signed; a rebuild can require a new explicit approval, but background reads fail silently with an inline connection message. Stable Developer ID signing is still required for the public distribution; this change does not create or claim a signing identity.

## Cursor

Reads only Cursor's access/refresh token entries from its local state database, opened read-only. If the app has no tokens, it checks the specific Cursor CLI Keychain services. It never combines tokens from these two sources. Requests go to Cursor's own `api2.cursor.sh` dashboard RPC and `cursor.com/api/usage-summary` / `api/usage` endpoints.

Shows reported plan, Cursor-model, and other-model percentages, exact billing-cycle resets, included request allowances where available, and separately labeled personal or team on-demand spending. Cursor's cent-denominated amounts are converted to dollars. Missing usage never becomes an invented zero. Expired access tokens can be refreshed through Cursor's OAuth endpoint; refreshed credentials stay in memory, without modifying Cursor's database or Keychain.

## Antigravity / Antigravity IDE

Uses the running app's language server when available. Discovery is restricted to the current user's Antigravity processes and ports confirmed by `lsof`; CSRF tokens are used only on loopback. The local server's self-signed certificate is accepted only for that exact loopback port. Remote endpoints use normal system certificate validation, and credentialed redirects are rejected.

The authoritative quota summary supplies shared Gemini and non-Gemini pools, each with five-hour and weekly windows. An authoritative empty summary stays empty. Older app builds fall back to reported per-model quotas, grouped conservatively into shared five-hour pools; missing model quotas are excluded, and weekly quotas are explicitly unavailable.

When the local service is unavailable, reads only the `gemini` / `antigravity` Keychain item using a silent native read cached for the session. An explicit Reconnect can use OpenUsage’s `/usr/bin/security find-generic-password` method (60-second timeout for the user to respond, normal macOS access controls, no credential logging) and calls Google's Cloud Code quota endpoints. OAuth refresh uses the public installed-app client shipped with Antigravity. Renewed Antigravity access tokens are cached at `~/Library/Application Support/HarnessManager/usage/antigravity/access.json` (directory 0700, file 0600). Entries expire 60 seconds before their reported expiry and are bound to a SHA-256 fingerprint of the source refresh credential. A changed source sign-in cannot reuse a previous account’s cache. Original Keychain credentials are never overwritten. Google OAuth renewal only follows an authentication rejection or absence of a usable token, not a transient network failure. Background Keychain reads remain silent. No conversation databases or prompts are read. Both Antigravity app variants use the same account pools, so the Usage page does not double-count them.

These undocumented provider protocols are adapted from [OpenUsage](https://github.com/robinebers/openusage), reference commit `7caf4caab4970701ccaeae3798a71e9995847001`. Upstream changes can require adapter updates. Its MIT license is included as `OpenUsage-LICENSE.txt` in the app resources.

## Refresh and coverage

Fetches on first opening, refreshes every five minutes while visible, and provides manual refresh. Providers fetch independently, so a slow response does not hold up other cards. The in-memory store survives navigation between pages. No usage history is saved to disk. Codex/OpenRouter failed refreshes retain the previous values with a timestamp and error. Cursor/Antigravity failures clear their previous values to avoid displaying another account's limits after a sign-in change. A passed reset time requires a fresh response; it is not assumed to restore the quota.

Claude has a dashboard shortcut. Configured providers with known dashboards also appear. These are explicitly not integrated yet; their subscription usage is not inferred from API-key detection or token counts.

Tests in `apps/mac/Tests/UsageTests.swift` cover multi-bucket precedence, legacy fallback, missing versus zero values, quota clamping, reset timestamps, uncapped keys, and recurring budgets. Run `apps/mac/Scripts/test-workflows.sh`.

## Additional provider connections

| Provider | Live data | Credentials / limits |
| --- | --- | --- |
| Claude | Five-hour, weekly, model-specific windows and extra usage | Existing default Claude Code Keychain login; credential-file fallback. Explicit Connect may authorize Keychain. Does not decrypt Claude Desktop or rotate Claude Code tokens; renew in Claude Code if expired. |
| OpenAI API | Current UTC month organization Costs API, all pages, currencies kept separate | Organization Admin key. No prepaid balance inferred. |
| Google Gemini API | Output tokens per model, previous 24h, all Cloud Monitoring pages | Project ID + Google Cloud OAuth access token with Monitoring permissions. Token replacement currently manual. No billing balance, input-token total, or remaining quota inferred. |
| xAI API | Team prepaid balance, converting negative ledger cents to available USD | Management API key + team ID. Not Grok subscription usage. |
| Z.ai | Coding Plan quota windows and web-search counts | Coding Plan API key. Same quota endpoint as OpenUsage. |
| MiniMax | Token Plan current/weekly remaining quota per model | Token Plan key. The remains API's `usage_count` means remaining. No PAYG balance. |
| Mistral | Organization monthly spending-limit-reached status | Admin key. Detailed billing amounts are **not yet implemented**. |
| Groq | Groq Console session; organization activity endpoint | Current UTC month requests, reported input/output tokens, and costs separated by plan. Free-plan cost is projected, not billed. No balance or remaining quota. Data may lag 15 minutes. |

Added connections validate a live response before saving their credentials in Keychain. HTTP redirects are rejected. No prompts or inference calls are sent. Empty/malformed data never becomes zero; paginated reports fail rather than publish a truncated sum. Provider errors are shown without printing credentials or raw server payloads.

References:
- OpenUsage Claude / Z.ai sources at pinned reference commit above.
- https://platform.openai.com/docs/api-reference/usage/costs
- https://docs.cloud.google.com/monitoring/api/metrics_gcp_d_h
- https://docs.x.ai/developers/rest-api-reference/management/billing
- https://docs.mistral.ai/admin/admin-api/usage-metrics
- https://docs.mistral.ai/api/endpoint/beta/admin/billing
- https://platform.minimax.io/subscribe/coding-plan
- https://github.com/steipete/CodexBar/blob/main/Sources/CodexBarCore/Providers/MiniMax/MiniMaxUsageFetcher.swift (response semantics reference; implementation written independently)
- https://console.groq.com/docs/api-reference

### Groq source and limitations

Verified against the first-party console JavaScript on September 21, 2026: `GET https://api.groq.com/platform/v1/organizations/{id}/activity?start_date={unixSeconds}&end_date={unixSeconds}`, with the console session JWT and `groq-organization` header. This is an undocumented console endpoint and may change. Responses are checked for organization mismatch and explicit pagination; incomplete cost rows suppress cost totals. No signed-in Groq account was available for end-to-end account verification during implementation.

- https://console.groq.com/dashboard/usage
- https://console.groq.com/_next/static/chunks/9342-52f3918d9f0a3630.js
- https://console.groq.com/_next/static/chunks/9808-92c5c643fb9e2f98.js

### First-run visibility

On a fresh installation, Usage waits for the completed local discovery scan and enables only detected installed/running tools and configured providers. All other providers start disabled. The initial selection is saved once; later scans and restarts never overwrite it. Explicit toggles made before discovery finishes also win. Existing legacy saved selections migrate unchanged. Detection is presence-only and does not prove that the required usage credential is configured.
