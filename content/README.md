# Product media

Harness Manager uses the same mac/web split as Port Radar. Its media pipeline adds native screenshot capture, so marketing always shows the shipping SwiftUI views.

1. `make native-shots` builds the app and captures nine native screens into `apps/web/public/screenshots`: six workspace views with isolated sample data, plus three Benchmarks views with real Modelgrep rankings (intelligence, coding, and design).
2. Inspect the captures. They use the actual app, not a browser reconstruction. Scanning and user-settings writes are disabled for capture mode.
3. `make package` creates the downloadable DMG.
4. `make web-build`, then `cd apps/web && npm run start` starts the production landing and press pages. Use the production server for media exports so development controls cannot appear in screenshots.
5. `make gallery PORT=3000` exports seven 2540 × 1520 gallery images into `content/product-hunt/media`, including the Benchmarks slide, and copies the overview to `content/reddit/share-image.png`.

The gallery uses varied layouts, bright silver and graphite backgrounds, readable type, and native captures. Chrome exports use a temporary profile and bounded runtime; they never reuse the user's browser profile. Native capture requires macOS and a graphical session. If macOS blocks capture, grant the invoking terminal/app screenshot permission and retry.

Do not independently redraw app UI in React or edit screenshots to show features the app does not have. Update the SwiftUI app, regenerate native captures, then regenerate the gallery. Marketing data is illustrative, clearly labeled, and contains no credentials or personal paths.

Benchmark capture fetches three public ranking collections through the app's production service and parser. It uses an in-memory store, never reads or writes the user's benchmark cache, and fails before replacing any existing PNGs if a collection cannot load. Rankings are snapshots at capture time, not live website results. The landing page links to full-size images and credits Modelgrep.

Landing positioning and reusable launch text are in `launch-copy.md`. No media or copy is published automatically by these commands.
