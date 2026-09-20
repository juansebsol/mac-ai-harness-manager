# Harness Manager

Your AI coding tools, together in one native Mac app. Discover harnesses, review updates, inspect your setup, and follow real harness news. Free and open source under Apache 2.0.

## Get the app

The website's **Download for Mac** button serves the packaged app. Requires macOS 14+; supports Apple silicon and Intel. The current 0.1.0 preview is ad-hoc signed and not notarized. No public release has been published yet. See [distribution](Docs/DISTRIBUTION.md) for packaging and release requirements.

## Repository

```text
apps/mac/   SwiftUI app, Xcode project, scripts, tests
apps/web/   Next.js product site, native screenshots, press pages
content/    Native and gallery capture scripts, exported launch media
Docs/       Design, architecture, distribution, validation
```

## Development

Xcode is needed only to develop/build the Mac app, not to use a packaged download.

```sh
make run           # Build and open the native app
make test          # Isolated install/update and news parser tests
make package       # Universal DMG + SHA-256 for the website
make native-shots  # Capture six real SwiftUI screens with sample data
cd apps/web && npm ci
```

From the root: `make web`, `make web-build`, and `make web-lint`. With the site running, `make gallery PORT=3000` produces six 2540 × 1520 press images. All media uses actual native app captures. See [media workflow](content/README.md).

More: [Mac app](apps/mac/README.md), [website](apps/web/README.md), [design](Docs/DESIGN.md), [structure](Docs/STRUCTURE.md).
