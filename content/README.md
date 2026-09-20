# Product media

Harness Manager uses the same mac/web split as Port Radar. Its media pipeline adds native screenshot capture, so marketing always shows the shipping SwiftUI views.

1. `make native-shots` builds the app and captures six native screens with sample data into `apps/web/public/screenshots`.
2. Inspect the captures. They use the actual app, not a browser reconstruction. Scanning and user-settings writes are disabled for capture mode.
3. `make package` creates the downloadable DMG.
4. `make web-build` and `make web` start the landing and press pages.
5. `make gallery PORT=3000` exports six 2540 × 1520 gallery images into `content/product-hunt/media`, and copies the overview to `content/reddit/share-image.png`.

The gallery uses varied layouts, bright silver and graphite backgrounds, readable type, and native captures. Chrome exports use a temporary profile and bounded runtime; they never reuse the user's browser profile. Native capture requires macOS and a graphical session. If macOS blocks capture, grant the invoking terminal/app screenshot permission and retry.

Do not independently redraw app UI in React or edit screenshots to show features the app does not have. Update the SwiftUI app, regenerate native captures, then regenerate the gallery. Marketing data is illustrative, clearly labeled, and contains no credentials or personal paths.
