# Workspace structure

Matches Port Radar's `apps/mac` + `apps/web` organization while retaining the native Xcode project.

- `apps/mac`: SwiftUI source, Xcode project, build/package scripts, isolated tests.
- `apps/web`: Next.js App Router product site, Motion tour, press gallery, native screenshot assets.
- `content`: repeatable native-window and browser gallery exports.
- `Docs`: design decisions, distribution requirements, validation evidence.

The root Makefile forwards common commands. The single web app owns its npm lockfile.

## One app, one visual source

SwiftUI RootView → isolated marketing capture mode → native PNGs → website and gallery.

`ProductTour` animates between native screenshots. It does not recreate the app or execute local commands. Six stable `/press/gallery/01..06` routes arrange the same screenshots for launch media. Static image imports hash the native screenshots, preventing stale optimizer caches after a redesign.

See [design](DESIGN.md), [media workflow](../content/README.md), and [distribution](DISTRIBUTION.md).
