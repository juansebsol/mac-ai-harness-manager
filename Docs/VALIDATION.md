# Validation

Validated 2026-09-19 against the final local app and production site.

- macOS universal Release build passed. `lipo` confirms x86_64 and arm64.
- Ad-hoc signature verification passed. The DMG's checksum and filesystem verification passed.
- Primary website download returned HTTP 200 with the 3,963,856-byte DMG.
- Installer/update tests passed for four package managers, prerequisite failures, unsupported sources, merged output, and nonzero exits. Tests use isolated fake commands; they do not install third-party tools.
- Native UI checks: Gemini CLI Install opens `npm install -g @google/gemini-cli`; Claude's update opens `claude update` with installed/latest versions. Both reviews were cancelled before execution.
- News parser tests passed for RSS, Atom, relevance filtering, safe URLs, HTML excerpts, dates, undated articles, and excluding prereleases. Downloaded live fixtures produced 100 relevant OpenAI entries, 2 Google Developers entries, 5 Simon Willison entries, and 3 Hacker News discussions. Counts naturally change.
- Native live news loaded current sourced articles and announcements. News & ideas is the default; Community and Releases are separate filters.
- Six actual app screenshots exported at 2400 × 1600. Screenshot settings are in memory; capture launch logs confirm existing saved window state is not touched.
- Six gallery images exported at 2540 × 1520 and inspected for layout and clipping. The website, tour, gallery, and standalone PNG links all share the native captures.
- ESLint, TypeScript, and Next.js production build passed. npm install reported zero vulnerabilities.
- Browser checks: desktop, 390 × 844 phone, light/dark, no horizontal overflow, keyboard tour tabs, manual pause, Play/Pause, full-size image link, and no console errors.
- Final Lighthouse mobile audit on localhost: Performance 93, Accessibility 100, Best Practices 100, SEO 100. LCP 3.2s, zero layout shift. Lab measurements vary by machine.

The website is running locally, not deployed. The preview DMG is ad-hoc signed and not notarized; a Developer ID identity and Apple notarization are still needed for general public distribution. No public GitHub release was created.
