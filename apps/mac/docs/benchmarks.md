# Benchmarks: Modelgrep

The native Benchmarks page uses only Modelgrep's public API:
`https://modelgrep.com/api/v1/models?sort=intelligence&limit=200`.

The Rankings view uses Modelgrep's published ranking endpoint, `https://modelgrep.com/api/v1/rankings/{collection}`. All 31 collections are grouped as General, Development, Reasoning & knowledge, Deployment, and Creative & specialist. Each collection is loaded only when selected and retains Modelgrep's rank, display value, numeric value, summary, and model links. Numeric values drive the chart directly; formatted display strings are never parsed into scores. Unscored entries remain in the model list.

Charts and Rankings have persistent top navigation. Categories scroll separately from results in a 214-point column; below 850 points of content width they become a compact picker. Changing category resets the result scroll and model search. Each comparison shows six models by default, with an option for ten, aligned names and scores, a shared zero baseline, and visible units. Search filters the fetched data and preserves original ranks. Modelgrep's longer assessment is expandable below ranking charts.

Each selected metric uses its corresponding sort key and `limit=200`: intelligence, coding, agentic, design, throughput, latency, or context. The first page is loaded on demand per metric, not the entire catalog. API pagination metadata is retained and the UI explains when more models exist. Search is local to the fetched results. Switching metrics fetches that metric's top 200, avoiding rankings drawn only from the intelligence subset.

Artificial Analysis indices, Design Arena Elo, output tokens/second, time-to-first-token milliseconds, and context tokens remain in their original units. Null/missing values are excluded; valid zero scores remain. Latency ranks ascending; other metrics rank descending. Ties are resolved deterministically by model ID. Modelgrep is an independent aggregator, not a verification authority. Its API does not supply the earlier verification flag, so that filter is removed. Design categories remain visible alongside model pricing context.

Cache: `~/Library/Caches/HarnessManager/modelgrep-v5.json`, one-hour freshness, checked on opening/switching and once a minute while the page is open. Manual Refresh bypasses freshness. Failed requests preserve the last successful snapshot. Empty, loading, offline/error, and cache-write failure states are explicit. No API key is required. The former Hugging Face cache is no longer read and no Hugging Face leaderboard requests remain.

Docs: https://modelgrep.com/api
