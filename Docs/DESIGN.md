# Harness Manager redesign

Audience: people who want to download and use a Mac utility for AI coding tools.
Reference: Port Radar's bright product media, focused feature stories, animated walkthrough, and download-first conversion flow.

## Audit and direction

The previous website led with source-build instructions, used a dark olive palette, had very little motion, and recreated a separate app interface in React. Its six press images repeated almost the same composition. The native app and website could drift apart.

Preserved: app icon, wordmark, orange accent, Geist fonts, existing routes and section anchors, local assets, keyboard access, privacy page, and the apps/mac + apps/web structure. Existing installation and update confirmation flows remain the command execution boundary.

New direction: silver, graphite, and orange. Large, restrained sans typography, varied editorial compositions, a guided product tour, and actual native screenshots. Native UI uses standard SwiftUI controls, readable tool cards, an actionable workspace summary, and grouped infrastructure views.

Design dials: DESIGN_VARIANCE 7 / MOTION_INTENSITY 6 / VISUAL_DENSITY 3.

The website opens in light mode. Its theme button offers dark mode without tracking or persistent storage. The tour starts when the visitor presses Play. Motion stops when reduced motion is requested or the tour is outside the viewport. Manual tab selection pauses the tour. Arrow keys and Home/End navigate the tabs.

## Authentic media

`content/capture-native.sh` runs the Release app with `--capture-marketing` and an isolated, in-memory SettingsStore. The app renders the same RootView used normally, with sample workspace data. Scanning and news network tasks are skipped. macOS screencapture exports only that app's window. Existing window state is ignored, not overwritten. It does not capture the desktop or other apps.

Native screenshot files are the shared source for the landing page, tour, feature sections, press pages, and gallery exports. Static imports add content hashes for cache correctness. No web recreation of the app remains.

Publisher titles and URLs in the sample news scene are real; screenshots are labeled sample workspace and do not claim to be a live feed. Tool versions and installed states in marketing fixtures are illustrative.
