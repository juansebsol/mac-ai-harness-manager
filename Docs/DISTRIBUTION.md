# Download and distribution

The primary website action downloads a Mac app, without requiring Xcode.

```sh
make package       # builds the universal Release app, creates DMG + SHA-256
make native-shots  # builds and exports six native screenshots
make web-build
make web
make gallery PORT=3000
```

The generated download is `apps/web/public/downloads/Harness-Manager.dmg`. It contains Harness Manager.app, an Applications shortcut, the Apache license, and installation notes. The app targets macOS 14+ on Apple silicon and Intel.

Release binaries are ignored by Git. To deploy, either generate/package the DMG before the website build, or set `NEXT_PUBLIC_DOWNLOAD_URL` to a real published HTTPS release asset. `prebuild` fails if neither exists, preventing a dead download button. Do not point to a hypothetical GitHub release. No release has been published by this change.

## Signing status

This workstation has no valid Developer ID signing identity. The generated preview is ad-hoc signed and not notarized. The website and DMG notes disclose this. Before a general public release, sign the app using the maintainer's Developer ID, notarize with Apple, staple the ticket, regenerate the DMG, and verify it on a clean Mac. The current build script deliberately makes only an ad-hoc development build; it does not claim notarization.

## News

The native app reads OpenAI and Google Developers RSS, Simon Willison's Atom feed, Hacker News story results through Algolia, and official Claude Code / Codex / Gemini CLI GitHub releases. Publisher articles are filtered for harness-related terms. Community posts are labeled separately. Drafts and prereleases are excluded from releases.

The default view is News & ideas. Articles have their original URL, source, category, and publisher date when supplied. Undated items say Date not provided. Excerpts are capped at 45 words. The app caches results locally, preserves stories from failed sources, deduplicates URLs, and retries on Refresh. It does not fabricate news or dates.
